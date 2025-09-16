// Config.swift
struct DigitalOceanConfig {
    let accessKey: String
    let secretKey: String
    let bucket: String
    let region: String
    
    // Computed properties for different endpoint formats
    var endpoint: String {
        // Base endpoint for DO Spaces API
        "https://\(region).digitaloceanspaces.com"
    }
    
    var cdnEndpoint: String {
        // Public URL format for accessing files
        "https://\(bucket).\(region).digitaloceanspaces.com"
    }
}

enum Config {
    static let digitalOcean = DigitalOceanConfig(
        accessKey: "DO00H8L8VR39BYAP777A",
        secretKey: "cbBeag/B5khmjKu+MaXqgsFEnAslAzc49UXMBdPjKdM",
        bucket: "supabase-c339da3c63034725",
        region: "nyc3"  // Remove the endpoint parameter as it's now computed
    )
}

