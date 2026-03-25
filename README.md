# PloyS3

PloyS3 is a cross-platform, S3-compatible file manager built with Flutter. It provides a clean, unified interface for browsing, uploading, and managing files across multiple storage backends, including S3-compatible cloud services, FTP, and SFTP. It also doubles as an image-hosting (picbed) tool with one-click Markdown link generation, and ships with first-class macOS integrations such as a persistent menu-bar icon and drag-and-drop uploads.

---

## Features

### Multi-Protocol Storage Support

PloyS3 connects to a wide range of storage backends through a single, consistent interface:

| Protocol | Typical Services |
|---|---|
| **S3-compatible** | AWS S3, Cloudflare R2, MinIO, Backblaze B2, and any S3-API-compatible endpoint |
| **FTP** | Any standard FTP server |
| **SFTP** | Any SSH/SFTP server (password or private-key authentication) |

You can save multiple server profiles and switch between them at any time. A built-in **Test Connection** button lets you verify credentials before saving a profile.

### File Management

- Browse buckets and directories with a familiar folder-tree interface.
- Upload one or many files at once with a live progress indicator.
- Download files directly to your device's downloads directory.
- Create and delete folders / prefixes.
- Rename objects.
- List view and grid view for browsing files.
- Multi-select for batch operations.
- Generate shareable public / CDN URLs for any object.

### Image Hosting (Picbed)

PloyS3 can act as a dedicated image-hosting tool:

- Configure a dedicated S3 server and upload directory specifically for image hosting.
- Configure a path template with variables such as `{year}`, `{month}`, `{day}`, `{timestamp}`, `{fileName}`, and `{ext}`.
- Choose a **naming strategy**: keep the original filename or generate a random name to avoid collisions.
- After every upload PloyS3 automatically copies the **Markdown image syntax** (`![](url)`) to your clipboard so you can paste it straight into any Markdown document.

### Multi-Platform Support

PloyS3 runs natively on both desktop and mobile platforms:

| Platform | Support |
|---|---|
| macOS | ✅ Full support, including menu-bar and drag-and-drop |
| Windows | ✅ Full support |
| Linux | ✅ Full support |
| iOS | ✅ Full support |
| Android | ✅ Full support |

### macOS-Specific Features

#### Menu-Bar App

PloyS3 can live permanently in the macOS menu bar. Once enabled in Settings, the app minimises to a small icon next to the clock. Clicking the icon opens a compact upload window without cluttering your Dock. The icon changes appearance to indicate the current upload state (idle, uploading, ready).

#### Drag-and-Drop Uploads

The fastest way to upload files on macOS:

1. **Drag files onto the menu-bar icon** — PloyS3 instantly queues them for upload using your configured image-hosting profile.
2. **Drag files into the upload window** — Drop any file onto the upload area inside the app to start uploading immediately.

No need to open a file picker or navigate to the destination bucket — just drag, drop, and copy the resulting URL.

### Upload & Download Queue

- All transfers are managed through a persistent queue visible in the app.
- Each item shows real-time progress.
- System notifications alert you when an upload or download finishes.

### Theming & Localisation

- Light, Dark, and System-follow themes.
- Internationalisation support (multi-language UI).
- Custom Alibaba PuHui Ti font for a polished look.

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (see `pubspec.yaml` for the minimum SDK version)
- Xcode (macOS / iOS builds)
- Android Studio or an Android SDK (Android builds)

### Clone & Run

```bash
git clone https://github.com/mylxsw/ploys3.git
cd ploys3
flutter pub get
flutter run
```

### Build for a Specific Platform

```bash
# macOS
make build-macos

# Install directly to /Applications
make install-macos

# Other platforms — use the standard Flutter build command
flutter build ios
flutter build apk
flutter build windows
flutter build linux
```

---

## Platform-Specific Configuration

Some platforms require additional entitlements or Info.plist entries before the app can open network connections. See [PLATFORM_SETUP.md](PLATFORM_SETUP.md) for the full details, including:

- **macOS** — App Sandbox network entitlements
- **iOS** — App Transport Security (ATS) exceptions for custom S3 endpoints
- **Android** — Standard internet permission (no extra steps needed)

---

## Configuration

### Adding a Storage Server

1. Open the app and tap/click the **"+"** button.
2. Choose the protocol type: **S3**, **FTP**, or **SFTP**.
3. Fill in the connection details (endpoint, bucket, credentials, etc.).
4. Tap **Test Connection** to verify the settings.
5. Save the profile.

### S3-Compatible Endpoint

| Field | Description |
|---|---|
| Endpoint | Full URL of the S3-compatible API (e.g. `https://s3.amazonaws.com`) |
| Bucket | Target bucket name |
| Access Key / Secret Key | IAM or service-account credentials |
| Region | AWS region or leave blank for non-AWS services |
| CDN URL | Optional base URL prepended to object paths when generating public links |

### Image Hosting (Picbed) Settings

Navigate to **Settings → Image Hosting** to:

- Select which server profile to use for image uploads.
- Set the upload path template (e.g. `images/{year}/{month}/` or `images/{year}/{fileName}.{ext}`).
- Choose the filename strategy (original or random).

---

## Dependencies

| Package | Purpose |
|---|---|
| `minio` | S3-compatible API client |
| `dartssh2` | SSH / SFTP client |
| `ftpconnect` | FTP client |
| `desktop_drop` | Drag-and-drop file support |
| `file_picker` | Native file-picker dialogs |
| `file_saver` | Save downloaded files to disk |
| `bitsdojo_window` | Custom desktop window chrome |
| `flutter_local_notifications` | System notifications for transfer events |
| `shared_preferences` | Persistent settings storage |
| `intl` | Internationalisation |

