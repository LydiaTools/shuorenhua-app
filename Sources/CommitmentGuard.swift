import Foundation

enum CommitmentGuard {
    private static let pattern = "(?:今天|明天|后天|本周|这周|下周|本月|月底|周[一二三四五六日天]|[0-9０-９一二三四五六七八九十]+(?:点|号|天|小时|周|个月|次|版)|保证|确保|一定|全部|完全|马上|立即|免费|无条件|按时完成|我来负责|我全包|都交给我)"

    static func detect(intention: String, reply: String, reported: [String] = []) -> [String] {
        var findings = reported
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !intention.contains($0) && hasUnsafeOccurrence(of: $0, in: reply) }
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return unique(findings) }
        let replyRange = NSRange(reply.startIndex..<reply.endIndex, in: reply)
        for match in expression.matches(in: reply, range: replyRange) {
            guard let range = Range(match.range, in: reply) else { continue }
            let value = String(reply[range])
            guard !intention.contains(value),
                  !isNegated(range: range, in: reply),
                  !isPurposeQualifier(value: value, range: range, in: reply) else { continue }
            findings.append(value)
        }
        return unique(findings)
    }

    private static func hasUnsafeOccurrence(of value: String, in text: String) -> Bool {
        var searchStart = text.startIndex
        while searchStart < text.endIndex,
              let range = text.range(of: value, range: searchStart..<text.endIndex) {
            if !isNegated(range: range, in: text),
               !isPurposeQualifier(value: value, range: range, in: text) {
                return true
            }
            searchStart = range.upperBound
        }
        return false
    }

    private static func isNegated(range: Range<String.Index>, in text: String) -> Bool {
        let prefixStart = text.index(range.lowerBound, offsetBy: -3, limitedBy: text.startIndex) ?? text.startIndex
        let prefix = String(text[prefixStart..<range.lowerBound])
        return ["不", "没", "无法", "不能", "不会", "不再", "不予"].contains { prefix.hasSuffix($0) }
    }

    private static func isPurposeQualifier(value: String,
                                           range: Range<String.Index>,
                                           in text: String) -> Bool {
        guard value == "保证" || value == "确保" else { return false }
        let prefixStart = text.index(range.lowerBound, offsetBy: -3, limitedBy: text.startIndex) ?? text.startIndex
        let prefix = String(text[prefixStart..<range.lowerBound])
        return ["为了", "为", "以便", "以"].contains { prefix.hasSuffix($0) }
    }

    private static func unique(_ values: [String]) -> [String] {
        var result: [String] = []
        for value in values where !value.isEmpty {
            if result.contains(where: { $0 == value || $0.contains(value) }) { continue }
            result.removeAll(where: { value.contains($0) })
            result.append(value)
            if result.count == 5 { break }
        }
        return result
    }
}
