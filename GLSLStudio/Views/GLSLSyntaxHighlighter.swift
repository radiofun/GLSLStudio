import SwiftUI
import UIKit

struct GLSLTextEditorView: UIViewRepresentable {
    @Binding var text: String
    @Binding var isEditing: Bool
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        
        let lineNumberView = LineNumberView()
        let textView = GLSLTextView()
        
        textView.delegate = context.coordinator
        textView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textColor = UIColor.label
        textView.isEditable = true
        textView.isScrollEnabled = true
        textView.showsVerticalScrollIndicator = true
        textView.showsHorizontalScrollIndicator = false
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        
        // Set line spacing for better readability
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4.0
        textView.typingAttributes = [
            .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular),
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ]
                
        // Setup constraints
        containerView.addSubview(lineNumberView)
        containerView.addSubview(textView)
        
        lineNumberView.translatesAutoresizingMaskIntoConstraints = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            lineNumberView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            lineNumberView.topAnchor.constraint(equalTo: containerView.topAnchor),
            lineNumberView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            lineNumberView.widthAnchor.constraint(equalToConstant: 50),
            
            textView.leadingAnchor.constraint(equalTo: lineNumberView.trailingAnchor),
            textView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            textView.topAnchor.constraint(equalTo: containerView.topAnchor),
            textView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Store references for updates
        textView.lineNumberView = lineNumberView
        lineNumberView.textView = textView
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Find the text view within the container
        if let textView = uiView.subviews.compactMap({ $0 as? GLSLTextView }).first {
            if textView.text != text {
                textView.text = text
                textView.applySyntaxHighlighting()
                textView.lineNumberView?.updateLineNumbers()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        let parent: GLSLTextEditorView
        
        init(_ parent: GLSLTextEditorView) {
            self.parent = parent
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isEditing = true
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            parent.isEditing = false
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            if let glslTextView = textView as? GLSLTextView {
                // Update line numbers immediately
                glslTextView.lineNumberView?.updateLineNumbers()
                
                // Delay syntax highlighting to avoid performance issues while typing
                NSObject.cancelPreviousPerformRequests(withTarget: glslTextView, selector: #selector(GLSLTextView.applySyntaxHighlighting), object: nil)
                glslTextView.perform(#selector(GLSLTextView.applySyntaxHighlighting), with: nil, afterDelay: 0.3)
            }
        }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // Auto-indentation on new line
            if text == "\n" {
                let currentText = textView.text as NSString
                let lineStart = currentText.lineRange(for: range).location
                let lineText = currentText.substring(with: NSRange(location: lineStart, length: range.location - lineStart))
                
                // Count leading whitespace
                let leadingWhitespace = String(lineText.prefix(while: { $0.isWhitespace }))
                
                // Add extra indentation after opening braces
                var indentation = leadingWhitespace
                if lineText.trimmingCharacters(in: .whitespaces).hasSuffix("{") {
                    indentation += "    " // 4 spaces
                }
                
                // Insert newline with indentation
                textView.insertText("\n" + indentation)
                return false
            }
            
            // Auto-close brackets and braces
            if text == "{" {
                textView.insertText("{}")
                // Move cursor back one position
                if let selectedRange = textView.selectedTextRange {
                    if let newPosition = textView.position(from: selectedRange.start, offset: -1) {
                        textView.selectedTextRange = textView.textRange(from: newPosition, to: newPosition)
                    }
                }
                return false
            }
            
            if text == "(" {
                textView.insertText("()")
                // Move cursor back one position
                if let selectedRange = textView.selectedTextRange {
                    if let newPosition = textView.position(from: selectedRange.start, offset: -1) {
                        textView.selectedTextRange = textView.textRange(from: newPosition, to: newPosition)
                    }
                }
                return false
            }
            
            return true
        }
    }
}

class GLSLTextView: UITextView {
    
    private let syntaxHighlighter = GLSLSyntaxHighlighter()
    weak var lineNumberView: LineNumberView?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupTextView()
    }
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupTextView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTextView()
    }
    
    private func setupTextView() {
        // Configure for code editing
        autocorrectionType = .no
        autocapitalizationType = .none
        smartQuotesType = .no
        smartDashesType = .no
        smartInsertDeleteType = .no
        
        // Add keyboard accessories for common GLSL characters
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        
        let semicolonButton = UIBarButtonItem(title: ";", style: .plain, target: self, action: #selector(insertSemicolon))
        let braceOpenButton = UIBarButtonItem(title: "{", style: .plain, target: self, action: #selector(insertOpenBrace))
        let braceCloseButton = UIBarButtonItem(title: "}", style: .plain, target: self, action: #selector(insertCloseBrace))
        let parenOpenButton = UIBarButtonItem(title: "(", style: .plain, target: self, action: #selector(insertOpenParen))
        let parenCloseButton = UIBarButtonItem(title: ")", style: .plain, target: self, action: #selector(insertCloseParen))
        let equalButton = UIBarButtonItem(title: "=", style: .plain, target: self, action: #selector(insertEqual))
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let hideButton = UIBarButtonItem(title: "Hide", style: .plain, target: self, action: #selector(hideKeyboard))
        
        toolbar.items = [semicolonButton, braceOpenButton, braceCloseButton, parenOpenButton, parenCloseButton, equalButton, flexSpace, hideButton]
        inputAccessoryView = toolbar
    }
    
    @objc private func insertSemicolon() { insertText(";") }
    @objc private func insertOpenBrace() { insertText("{") }
    @objc private func insertCloseBrace() { insertText("}") }
    @objc private func insertOpenParen() { insertText("(") }
    @objc private func insertCloseParen() { insertText(")") }
    @objc private func insertEqual() { insertText("=") }
    
    @objc private func hideKeyboard() {
        resignFirstResponder()
    }
    
    @objc func applySyntaxHighlighting() {
        let currentRange = selectedRange
        let attributedText = syntaxHighlighter.highlight(text: text)
        self.attributedText = attributedText
        selectedRange = currentRange
        lineNumberView?.updateLineNumbers()
    }
}

class GLSLSyntaxHighlighter {
    
    // Colors optimized for both light and dark mode
    private var keywordColor: UIColor { 
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor.systemPurple : UIColor.systemPurple
        }
    }
    
    private var typeColor: UIColor {
        UIColor.label
    }
    
    private var functionColor: UIColor {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor.systemTeal : UIColor.systemTeal
        }
    }
    
    private var commentColor: UIColor {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor.systemGreen : UIColor.systemGreen
        }
    }
    
    private var stringColor: UIColor {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor.systemRed : UIColor.systemRed
        }
    }
    
    private var numberColor: UIColor {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor.systemOrange : UIColor.systemOrange
        }
    }
    
    private var builtinColor: UIColor {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor.systemIndigo : UIColor.systemIndigo
        }
    }
    
    private var textColor: UIColor { UIColor.label }
    
    private let keywords = [
        "attribute", "const", "uniform", "varying", "break", "continue", "do", "for", "while",
        "if", "else", "in", "out", "inout", "true", "false", "discard", "return", "struct",
        "precision", "highp", "mediump", "lowp", "invariant", "centroid", "flat", "smooth",
        "noperspective", "layout", "binding", "location"
    ]
    
    private let types = [
        "void", "bool", "int", "float", "double",
        "bvec2", "bvec3", "bvec4",
        "ivec2", "ivec3", "ivec4",
        "uvec2", "uvec3", "uvec4",
        "vec2", "vec3", "vec4",
        "dvec2", "dvec3", "dvec4",
        "mat2", "mat3", "mat4",
        "mat2x2", "mat2x3", "mat2x4",
        "mat3x2", "mat3x3", "mat3x4",
        "mat4x2", "mat4x3", "mat4x4",
        "dmat2", "dmat3", "dmat4",
        "sampler1D", "sampler2D", "sampler3D", "samplerCube",
        "sampler1DShadow", "sampler2DShadow", "samplerCubeShadow",
        "sampler1DArray", "sampler2DArray",
        "isampler1D", "isampler2D", "isampler3D", "isamplerCube",
        "usampler1D", "usampler2D", "usampler3D", "usamplerCube"
    ]
    
    private let builtinFunctions = [
        "radians", "degrees", "sin", "cos", "tan", "asin", "acos", "atan", "sinh", "cosh", "tanh",
        "pow", "exp", "log", "exp2", "log2", "sqrt", "inversesqrt",
        "abs", "sign", "floor", "ceil", "fract", "mod", "min", "max", "clamp", "mix", "step", "smoothstep",
        "length", "distance", "dot", "cross", "normalize", "faceforward", "reflect", "refract",
        "matrixCompMult", "outerProduct", "transpose", "determinant", "inverse",
        "lessThan", "lessThanEqual", "greaterThan", "greaterThanEqual", "equal", "notEqual", "any", "all", "not",
        "texture", "texture2D", "textureProj", "textureLod", "textureSize", "texelFetch"
    ]
    
    private let builtinVariables = [
        "gl_Position", "gl_PointSize", "gl_ClipDistance",
        "gl_FragCoord", "gl_FrontFacing", "gl_ClipDistance", "gl_PointCoord",
        "gl_FragColor", "gl_FragData", "gl_FragDepth",
        "gl_VertexID", "gl_InstanceID", "gl_PrimitiveID",
        "gl_MaxVertexAttribs", "gl_MaxVertexUniformComponents", "gl_MaxVaryingFloats",
        "gl_MaxVertexTextureImageUnits", "gl_MaxTextureImageUnits", "gl_MaxFragmentUniformComponents",
        "gl_MaxCombinedTextureImageUnits", "gl_MaxDrawBuffers"
    ]
    
    func highlight(text: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        let range = NSRange(location: 0, length: text.count)
        
        // Set base attributes with line spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4.0
        
        attributedString.addAttribute(.foregroundColor, value: textColor, range: range)
        attributedString.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular), range: range)
        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
        
        // Apply syntax highlighting
        highlightComments(in: attributedString)
        highlightStrings(in: attributedString)
        highlightNumbers(in: attributedString)
        highlightKeywords(in: attributedString)
        highlightTypes(in: attributedString)
        highlightBuiltinFunctions(in: attributedString)
        highlightBuiltinVariables(in: attributedString)
        
        return attributedString
    }
    
    private func highlightComments(in attributedString: NSMutableAttributedString) {
        // Single line comments
        let singleLinePattern = "//.*$"
        highlightPattern(singleLinePattern, in: attributedString, color: commentColor, options: [.anchorsMatchLines])
        
        // Multi-line comments
        let multiLinePattern = "/\\*[\\s\\S]*?\\*/"
        highlightPattern(multiLinePattern, in: attributedString, color: commentColor)
    }
    
    private func highlightStrings(in attributedString: NSMutableAttributedString) {
        let pattern = "\".*?\""
        highlightPattern(pattern, in: attributedString, color: stringColor)
    }
    
    private func highlightNumbers(in attributedString: NSMutableAttributedString) {
        let pattern = "\\b\\d+\\.?\\d*[fF]?\\b"
        highlightPattern(pattern, in: attributedString, color: numberColor)
    }
    
    private func highlightKeywords(in attributedString: NSMutableAttributedString) {
        for keyword in keywords {
            let pattern = "\\b\(keyword)\\b"
            highlightPattern(pattern, in: attributedString, color: keywordColor)
        }
    }
    
    private func highlightTypes(in attributedString: NSMutableAttributedString) {
        for type in types {
            let pattern = "\\b\(type)\\b"
            highlightPattern(pattern, in: attributedString, color: typeColor)
        }
    }
    
    private func highlightBuiltinFunctions(in attributedString: NSMutableAttributedString) {
        for function in builtinFunctions {
            let pattern = "\\b\(function)\\b"
            highlightPattern(pattern, in: attributedString, color: functionColor)
        }
    }
    
    private func highlightBuiltinVariables(in attributedString: NSMutableAttributedString) {
        for variable in builtinVariables {
            let pattern = "\\b\(variable)\\b"
            highlightPattern(pattern, in: attributedString, color: builtinColor)
        }
    }
    
    private func highlightPattern(_ pattern: String, in attributedString: NSMutableAttributedString, color: UIColor, options: NSRegularExpression.Options = []) {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: options)
            let range = NSRange(location: 0, length: attributedString.length)
            let matches = regex.matches(in: attributedString.string, options: [], range: range)
            
            for match in matches.reversed() {
                attributedString.addAttribute(.foregroundColor, value: color, range: match.range)
            }
        } catch {
            print("Regex error: \(error)")
        }
    }
}

class LineNumberView: UIView {
    weak var textView: UITextView?
    private let label = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor.secondaryLabel
        label.textAlignment = .right
        label.numberOfLines = 0
        label.backgroundColor = UIColor.clear
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            label.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor)
        ])
        
    }
    
    func updateLineNumbers() {
        guard let textView = textView else { return }
        
        let text = textView.text ?? ""
        let lineCount = text.components(separatedBy: .newlines).count
        
        var lineNumbers = ""
        for i in 1...max(lineCount, 1) {
            lineNumbers += "\(i)\n"
        }
        
        // Create attributed string with matching line spacing
        let attributedLineNumbers = NSMutableAttributedString(string: String(lineNumbers.dropLast()))
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4.0
        paragraphStyle.alignment = .right
        
        let range = NSRange(location: 0, length: attributedLineNumbers.length)
        attributedLineNumbers.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
        attributedLineNumbers.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: 12, weight: .regular), range: range)
        attributedLineNumbers.addAttribute(.foregroundColor, value: UIColor.secondaryLabel, range: range)
        
        label.attributedText = attributedLineNumbers
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            layer.borderColor = UIColor.separator.cgColor
        }
    }
}
