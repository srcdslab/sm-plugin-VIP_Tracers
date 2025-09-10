# Copilot Instructions for VIP Tracers Plugin

## Repository Overview

This repository contains a SourceMod plugin that provides VIP players with visual bullet tracers - colorful lines that show the trajectory of bullets when firing weapons. The plugin integrates with the VIP Core system and provides extensive customization options for tracer appearance and behavior.

### Key Components
- **Main Plugin**: `addons/sourcemod/scripting/VIP_Tracers.sp` - Core plugin functionality
- **Configuration**: `addons/sourcemod/configs/tracers.cfg` - Plugin settings and color definitions
- **Translations**: `addons/sourcemod/translations/vip_tracers.phrases.txt` - Multi-language support
- **Build System**: `sourceknight.yaml` - SourceKnight build configuration
- **CI/CD**: `.github/workflows/ci.yml` - Automated building and releases

## Technical Environment

- **Language**: SourcePawn (SourceMod scripting language)
- **Platform**: SourceMod 1.11.0+ (supports up to latest 1.12+)
- **Compiler**: SourcePawn compiler (spcomp) via SourceKnight
- **Dependencies**:
  - SourceMod core
  - VIP Core plugin (for VIP system integration)
  - MultiColors include (for colored chat messages)

## Code Style & Standards

### SourcePawn Conventions
- Use `#pragma semicolon 1` and `#pragma newdecls required` (already implemented)
- Indentation: 4 spaces (use tabs in this project to match existing code)
- Variable naming:
  - Global variables: prefix with `g_` (e.g., `g_bHasAccess`)
  - Local variables: camelCase
  - Functions: PascalCase
  - Constants: UPPER_CASE

### Memory Management
- Use `delete` for Handle cleanup instead of `CloseHandle()` 
- No need to check for null before calling `delete`
- Avoid `.Clear()` on StringMap/ArrayList - use `delete` and recreate instead
- Properly handle memory allocation/deallocation

### Modern SourcePawn Practices
- Prefer methodmaps over Handle-based APIs where possible
- Use new syntax instead of old-style declarations
- All SQL queries must be asynchronous using methodmaps
- Use transactions for SQL operations when needed

### Project-Specific Conventions
- Follow existing code style in the plugin (currently uses some older conventions)
- When modernizing code, do so incrementally to maintain compatibility
- Maintain backward compatibility with SourceMod 1.11.0+

## Development Workflow

### Build System
The project uses SourceKnight for building:

```bash
# Build the plugin (requires SourceKnight installed)
sourceknight build
```

The build process:
1. Downloads dependencies (SourceMod, MultiColors, VIP Core)
2. Compiles the SourcePawn script
3. Packages the plugin with configs and translations
4. Outputs to `.sourceknight/package/`

### File Structure
```
addons/sourcemod/
├── scripting/
│   └── VIP_Tracers.sp          # Main plugin source
├── configs/
│   └── tracers.cfg             # Configuration file
└── translations/
    └── vip_tracers.phrases.txt # Translation phrases
```

### Dependencies Management
Dependencies are automatically handled by SourceKnight:
- SourceMod base files
- VIP Core includes (`vip_core.inc`)
- MultiColors includes (`multicolors.inc`)

## Plugin Architecture

### Core Functionality
- **VIP Integration**: Hooks into VIP Core system for access control
- **Event Handling**: Listens to `bullet_impact` events to draw tracers
- **Client Preferences**: Uses SourceMod cookies for persistent settings
- **Menu System**: Provides in-game menus for tracer customization

### Key Systems
1. **Access Control**: VIP status determines plugin access
2. **Tracer Rendering**: Uses `TE_SetupBeamPoints` for visual effects
3. **Color Management**: Supports RGB colors, random colors, and team colors
4. **Configuration**: Loads settings from KeyValues config file
5. **Localization**: Multi-language support via phrase files

### Configuration Options
- Tracer lifetime, width, amplitude
- Team visibility settings (hide from opposite team)
- Material/sprite customization
- Color palette definitions

## Common Development Tasks

### Adding New Features
1. Follow existing code patterns for consistency
2. Add configuration options to `tracers.cfg` if needed
3. Add translation keys to phrase file for user-facing text
4. Test with different SourceMod versions (minimum 1.11.0)

### Debugging
- Use SourceMod's built-in logging: `LogMessage()`, `LogError()`
- Test on development server before production deployment
- Check console for compilation warnings/errors
- Use SourceMod's profiler for performance analysis

### Performance Considerations
- Tracer rendering occurs on every bullet impact - optimize carefully
- Minimize operations in `Event_BulletImpact` handler
- Cache expensive calculations where possible
- Consider server tick rate impact for high-frequency operations

## Testing Guidelines

### Manual Testing
1. Test VIP access control (VIP vs non-VIP players)
2. Verify tracer visibility settings work correctly
3. Test all color options including random and team colors
4. Validate menu navigation and cookie persistence
5. Test with different weapon types and firing patterns

### Compatibility Testing
- Test with minimum SourceMod version (1.11.0)
- Verify compatibility with latest SourceMod builds
- Test with various Source engine games
- Ensure proper integration with VIP Core plugin

## Common Code Patterns

### Event Handling
```sourcepawn
public Event_BulletImpact(Handle:hEvent, const String:sEvName[], bool:dontBroadcast)
{
    new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
    // Handle bullet impact for tracer rendering
}
```

### Cookie Management
```sourcepawn
public OnClientCookiesCached(iClient)
{
    // Load client preferences from cookies
    // Set defaults if no cookies exist
}
```

### VIP Integration
```sourcepawn
public void VIP_OnVIPClientLoaded(int client)
{
    // Grant access when VIP status is confirmed
    g_bHasAccess[client] = true;
}
```

## Troubleshooting

### Common Issues
- **Tracers not visible**: Check VIP access and visibility settings
- **Build failures**: Verify SourceKnight dependencies are available
- **Color issues**: Validate color format in config file (R G B A)
- **Performance problems**: Profile tracer rendering frequency

### Debug Steps
1. Check SourceMod error logs
2. Verify plugin loaded successfully (`sm plugins list`)
3. Test VIP Core integration (`sm_vip_reload`)
4. Validate configuration file syntax

## Release Process

### Automated Releases
The CI/CD pipeline automatically:
1. Builds the plugin on push/PR
2. Creates releases with compiled plugins
3. Packages configs and translations
4. Tags releases appropriately

### Manual Release Steps
1. Update version in plugin info
2. Update changelog if applicable
3. Test thoroughly on development server
4. Create tag following semantic versioning
5. CI will automatically create release

## Best Practices Summary

- Always test VIP integration thoroughly
- Optimize tracer rendering for performance
- Use translation keys for all user-facing text
- Follow existing code style for consistency
- Validate configuration changes don't break existing setups
- Consider backwards compatibility when making changes
- Use proper error handling for all API calls
- Document complex logic with inline comments