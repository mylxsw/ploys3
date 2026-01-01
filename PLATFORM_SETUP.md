# Platform-Specific Setup for S3/R2 Connections

This document explains the platform-specific configurations required for the app to connect to S3-compatible services like Cloudflare R2.

## macOS Setup

### Network Permissions

The macOS app requires network permissions to connect to external services. The following entitlements have been added:

- `com.apple.security.network.client` - Allows the app to make outgoing network connections
- `com.apple.security.network.server` - Allows the app to receive incoming network connections (Debug/Profile builds only)

These are configured in:
- `macos/Runner/DebugProfile.entitlements`
- `macos/Runner/Release.entitlements`

### App Sandbox

The app uses macOS App Sandbox for security. The sandbox allows controlled access to system resources while maintaining security.

## iOS Setup

### App Transport Security (ATS)

iOS requires explicit permissions for non-HTTPS connections and custom domains. The following configuration has been added to `ios/Runner/Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
    <key>NSAllowsArbitraryLoadsInWebContent</key>
    <true/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>r2.cloudflarestorage.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
            <key>NSExceptionMinimumTLSVersion</key>
            <string>TLSv1.2</string>
            <key>NSIncludesSubdomains</key>
            <true/>
            <key>NSThirdPartyExceptionRequiresForwardSecrecy</key>
            <false/>
        </dict>
    </dict>
</dict>
```

This configuration:
- Allows connections to R2 endpoints
- Permits both HTTP and HTTPS connections
- Sets minimum TLS version to 1.2
- Allows connections to all R2 subdomains
- Disables forward secrecy requirement for third-party connections

## Android Setup

No special configuration is required for Android. The app automatically has internet access permissions through the standard Android manifest.

## Troubleshooting

### "Operation not permitted" Error

If you see this error on macOS:
1. Ensure you're running the app with proper permissions
2. Check that the entitlements are correctly configured
3. For development, use Debug or Profile builds which have additional permissions

### Connection Issues on iOS

If connections fail on iOS:
1. Verify the NSAppTransportSecurity settings in Info.plist
2. Check that your endpoint URL is correctly formatted
3. Ensure your device/simulator has internet connectivity

### General Connection Issues

1. Use the "Test Connection" feature in the app to diagnose connection problems
2. Check the debug output for detailed error messages
3. Verify your S3/R2 credentials and endpoint configuration

## Development vs Release Builds

- **Debug/Profile builds**: Have more permissive settings for development
- **Release builds**: Have stricter security settings for production

Make sure to test with the appropriate build configuration for your use case.