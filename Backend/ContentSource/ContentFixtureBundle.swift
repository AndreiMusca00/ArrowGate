import Foundation

/// Gives Swift Package tests access to the authoring catalog without placing
/// that catalog inside the iOS application target.
public enum ContentFixtureBundle {
    public static var bundle: Bundle { Bundle.module }
}
