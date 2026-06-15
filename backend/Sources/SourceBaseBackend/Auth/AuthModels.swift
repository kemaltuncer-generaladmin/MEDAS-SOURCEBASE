import Foundation
import Supabase

public enum AuthResult: Sendable {
    case success(String, user: User? = nil)
    case failure(String)

    public var ok: Bool {
        if case .success = self { return true }
        return false
    }

    public var message: String? {
        if case .success(let msg, _) = self { return msg }
        return nil
    }

    public var error: String? {
        if case .failure(let err) = self { return err }
        return nil
    }

    public var user: User? {
        if case .success(_, let user) = self { return user }
        return nil
    }
}

public struct AuthCallbackResult: Sendable {
    public let redirectType: String?

    public var isPasswordRecovery: Bool {
        redirectType == "recovery" || redirectType == "passwordRecovery"
    }
}

public struct SourceBaseProfile: Sendable {
    public let faculty: String
    public let department: String
    /// e.g. "Dönem 3", "Mezun" — drives how deep/foundational AI output should be.
    public let classYear: String
    /// e.g. "TUS", "Dönem sınavları", "USMLE", "Genel tekrar" — drives AI focus.
    public let goal: String

    public init(
        faculty: String,
        department: String,
        classYear: String = "",
        goal: String = ""
    ) {
        self.faculty = faculty.trimmingCharacters(in: .whitespaces)
        self.department = department.trimmingCharacters(in: .whitespaces)
        self.classYear = classYear.trimmingCharacters(in: .whitespaces)
        self.goal = goal.trimmingCharacters(in: .whitespaces)
    }

    public func metadata() -> [String: Any] {
        [
            "sourcebase_faculty": faculty,
            "sourcebase_department": department,
            "sourcebase_class_year": classYear,
            "sourcebase_goal": goal,
            "sourcebase_profile_completed": true,
            "sourcebase_profile_completed_at": ISO8601DateFormatter().string(from: Date())
        ]
    }

    /// Compact persona string fed to the AI so every generation is tailored to the
    /// student's level and exam target.
    public var studentContext: String {
        var parts: [String] = []
        if !department.isEmpty { parts.append(department) }
        if !classYear.isEmpty { parts.append(classYear) }
        if !goal.isEmpty { parts.append("hedef: \(goal)") }
        if !faculty.isEmpty { parts.append(faculty) }
        return parts.joined(separator: " · ")
    }
}
