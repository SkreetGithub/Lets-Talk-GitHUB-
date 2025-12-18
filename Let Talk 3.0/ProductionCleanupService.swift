import Foundation
import SwiftUI

// MARK: - Production Cleanup Service
class ProductionCleanupService {
    static let shared = ProductionCleanupService()
    
    private init() {}
    
    // MARK: - Remove Demo Data
    func removeDemoData() {
        // Remove demo contacts
        UserDefaults.standard.removeObject(forKey: "demoContacts")
        UserDefaults.standard.removeObject(forKey: "sampleContacts")
        
        // Remove demo messages
        UserDefaults.standard.removeObject(forKey: "demoMessages")
        UserDefaults.standard.removeObject(forKey: "sampleMessages")
        
        // Remove demo translations
        UserDefaults.standard.removeObject(forKey: "demoTranslations")
        UserDefaults.standard.removeObject(forKey: "sampleTranslations")
        
        // Remove demo call history
        UserDefaults.standard.removeObject(forKey: "demoCallHistory")
        UserDefaults.standard.removeObject(forKey: "sampleCallHistory")
        
        // Remove demo user data
        UserDefaults.standard.removeObject(forKey: "demoUser")
        UserDefaults.standard.removeObject(forKey: "sampleUser")
        
        // Remove demo settings
        UserDefaults.standard.removeObject(forKey: "demoSettings")
        UserDefaults.standard.removeObject(forKey: "sampleSettings")
        
        // Remove demo mode flag
        UserDefaults.standard.removeObject(forKey: "isDemoMode")
        UserDefaults.standard.removeObject(forKey: "demoMode")
        
        // Remove placeholder data
        UserDefaults.standard.removeObject(forKey: "placeholderData")
        UserDefaults.standard.removeObject(forKey: "mockData")
        
        // Remove test data
        UserDefaults.standard.removeObject(forKey: "testData")
        UserDefaults.standard.removeObject(forKey: "testContacts")
        UserDefaults.standard.removeObject(forKey: "testMessages")
        
        print("Demo data removed successfully")
    }
    
    // MARK: - Clean User Defaults
    func cleanUserDefaults() {
        let keysToRemove = [
            "demoContacts", "sampleContacts", "demoMessages", "sampleMessages",
            "demoTranslations", "sampleTranslations", "demoCallHistory", "sampleCallHistory",
            "demoUser", "sampleUser", "demoSettings", "sampleSettings",
            "isDemoMode", "demoMode", "placeholderData", "mockData",
            "testData", "testContacts", "testMessages"
        ]
        
        for key in keysToRemove {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        print("UserDefaults cleaned successfully")
    }
    
    // MARK: - Validate Production Readiness
    func validateProductionReadiness() -> [String] {
        var issues: [String] = []
        
        // Check for demo data
        if UserDefaults.standard.object(forKey: "demoContacts") != nil {
            issues.append("Demo contacts still present")
        }
        
        if UserDefaults.standard.object(forKey: "demoMessages") != nil {
            issues.append("Demo messages still present")
        }
        
        if UserDefaults.standard.object(forKey: "isDemoMode") != nil {
            issues.append("Demo mode flag still present")
        }
        
        // Check for placeholder data
        if UserDefaults.standard.object(forKey: "placeholderData") != nil {
            issues.append("Placeholder data still present")
        }
        
        // Check for test data
        if UserDefaults.standard.object(forKey: "testData") != nil {
            issues.append("Test data still present")
        }
        
        return issues
    }
    
    // MARK: - Production Configuration
    func configureForProduction() {
        // Remove demo mode
        UserDefaults.standard.set(false, forKey: "isDemoMode")
        UserDefaults.standard.set(false, forKey: "demoMode")
        
        // Set production flags
        UserDefaults.standard.set(true, forKey: "isProductionMode")
        UserDefaults.standard.set(true, forKey: "productionReady")
        
        // Remove debug flags
        UserDefaults.standard.set(false, forKey: "debugMode")
        UserDefaults.standard.set(false, forKey: "showDebugInfo")
        
        // Set release configuration
        UserDefaults.standard.set("production", forKey: "appEnvironment")
        UserDefaults.standard.set("release", forKey: "buildConfiguration")
        
        print("App configured for production")
    }
    
    // MARK: - Complete Cleanup
    func performCompleteCleanup() {
        removeDemoData()
        cleanUserDefaults()
        configureForProduction()
        
        // Force UserDefaults to save
        UserDefaults.standard.synchronize()
        
        print("Complete production cleanup performed")
    }
}

// MARK: - Demo Data Detection
extension ProductionCleanupService {
    func containsDemoData() -> Bool {
        let demoKeys = [
            "demoContacts", "sampleContacts", "demoMessages", "sampleMessages",
            "demoTranslations", "sampleTranslations", "demoCallHistory", "sampleCallHistory",
            "demoUser", "sampleUser", "demoSettings", "sampleSettings",
            "isDemoMode", "demoMode", "placeholderData", "mockData",
            "testData", "testContacts", "testMessages"
        ]
        
        return demoKeys.contains { UserDefaults.standard.object(forKey: $0) != nil }
    }
    
    func getDemoDataCount() -> Int {
        let demoKeys = [
            "demoContacts", "sampleContacts", "demoMessages", "sampleMessages",
            "demoTranslations", "sampleTranslations", "demoCallHistory", "sampleCallHistory",
            "demoUser", "sampleUser", "demoSettings", "sampleSettings",
            "isDemoMode", "demoMode", "placeholderData", "mockData",
            "testData", "testContacts", "testMessages"
        ]
        
        return demoKeys.filter { UserDefaults.standard.object(forKey: $0) != nil }.count
    }
}
