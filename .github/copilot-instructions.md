# SourceMod VIP Test Plugin - Copilot Instructions

## Repository Overview

This repository contains a SourcePawn plugin for SourceMod that implements a VIP Test system. The plugin allows players to test VIP features for a configurable duration with cooldown periods to prevent abuse. It integrates with the VIP Core plugin system and supports both MySQL and SQLite databases.

**Key Features:**
- Time-limited VIP status testing
- Database persistence with cooldown management
- Multi-language support (Russian, English, Finnish, French)
- Admin controls for managing test data
- Comprehensive logging and error handling

## Technical Environment

- **Language**: SourcePawn (.sp files)
- **Platform**: SourceMod 1.11+ (currently using 1.11.0-git6917)
- **Build System**: SourceKnight (configured in `sourceknight.yaml`)
- **Database**: MySQL (preferred) or SQLite fallback
- **Dependencies**: VIP Core plugin from srcdslab/sm-plugin-VIP-Core

## Build System & Development Workflow

### SourceKnight Configuration
The project uses SourceKnight for building. Key configuration in `sourceknight.yaml`:
- Dependencies are automatically downloaded (SourceMod + VIP Core)
- Output goes to `/addons/sourcemod/plugins`
- Target: `VIP_Test` (produces VIP_Test.smx)

### CI/CD Pipeline
- Automated builds on push/PR via GitHub Actions
- Uses `maxime1907/action-sourceknight@v1`
- Creates packages with plugins and translations
- Automatic releases with version tagging

### Building Locally
```bash
# If SourceKnight is installed
sourceknight build

# Manual compilation (requires SourceMod compiler and includes)
spcomp -i"includes" VIP_Test.sp
```

## Project Structure

```
addons/sourcemod/
├── scripting/
│   └── VIP_Test.sp              # Main plugin source
└── translations/
    └── vip_test.phrases.txt     # Multi-language translations
```

**Key directories:**
- `addons/sourcemod/scripting/` - Source code (.sp files)
- `addons/sourcemod/translations/` - Language files
- `addons/sourcemod/plugins/` - Compiled plugins (build output)

## Code Style & Standards

### Formatting
- Indentation: 4 spaces (tabs configured as 4 spaces)
- Line endings: LF (Unix style)
- No trailing whitespace
- Pragma directives: `#pragma semicolon 1` and `#pragma newdecls required`

### Naming Conventions
- **Functions**: PascalCase (`OnPluginStart`, `GiveVIPToClient`)
- **Variables**: 
  - Local/parameters: camelCase (`iClient`, `sAuth`)
  - Global: "g_" prefix + descriptive name (`g_hDatabase`, `g_iTestTime`)
- **Constants/Defines**: UPPER_CASE (`DB_CHARSET`, `DB_COLLATION`)

### Code Organization
- Group related functionality together
- Use stock functions for reusable code
- Implement proper error handling for all database operations
- Use translation keys for all user-facing messages

## Database Patterns

### Connection Management
```sourcepawn
// Always use async connections
SQL_TConnect(DB_OnConnect, "vip_test", 1);

// Support both MySQL and SQLite
if (SQL_CheckConfig("vip_test")) {
    // MySQL from databases.cfg
} else {
    // SQLite fallback
    g_hDatabase = SQLite_UseDatabase("vip_test", sError, sizeof(sError));
}
```

### Query Patterns
```sourcepawn
// All queries MUST be asynchronous
SQL_TQuery(g_hDatabase, SQL_Callback_Function, sQuery, clientUserId);

// Always escape user input (though SteamID2 is relatively safe)
// Use proper format strings for queries
FormatEx(sQuery, sizeof(sQuery), "SELECT `end` FROM `vip_test` WHERE `auth` = '%s' LIMIT 1;", sAuth);
```

### Best Practices
- All SQL operations are asynchronous (no blocking calls)
- Use transactions for multi-query operations
- Implement proper error checking in callbacks
- Support both MySQL (with UTF8MB4) and SQLite
- Use parameterized queries where possible

## Translation System

### File Structure
Translation files use SourceMod's phrase system:
```
"Phrases"
{
    "PHRASE_KEY"
    {
        "en"    "English text"
        "ru"    "Russian text"
        "fi"    "Finnish text"
        "fr"    "French text"
    }
}
```

### Usage Patterns
```sourcepawn
// Load translations in OnPluginStart
LoadTranslations("vip_test.phrases");
LoadTranslations("vip_core.phrases");

// Use in code
VIP_PrintToChatClient(iClient, "%t", "PHRASE_KEY");
VIP_PrintToChatClient(iClient, "%t", "PHRASE_WITH_PARAM", paramValue);
```

## Memory Management

### Handle Management
```sourcepawn
// Use 'delete' for cleanup - no null checking needed
delete hHandle;

// For StringMaps/ArrayLists: delete and recreate instead of .Clear()
delete g_hMap;
g_hMap = new StringMap();
```

### ConVar Management
```sourcepawn
// Store ConVar references for change hooks
ConVar hCvar = CreateConVar("cvar_name", "default", "description");
hCvar.AddChangeHook(OnCvarChange);
```

## Plugin Integration

### VIP Core Integration
```sourcepawn
// Check VIP status
if (VIP_IsClientVIP(iClient)) { /* handle */ }

// Grant VIP status
VIP_GiveClientVIP(_, iClient, seconds, group, false);

// Use VIP messaging system
VIP_PrintToChatClient(iClient, "%t", "message_key");

// Logging through VIP Core
VIP_LogMessage("Player %N received VIP-Test status", iClient);
```

## Common Development Tasks

### Adding New Console Commands
```sourcepawn
// In OnPluginStart()
RegConsoleCmd("sm_command", Command_Function);
RegAdminCmd("sm_admincommand", AdminCommand_Function, ADMFLAG_ROOT);

// Command handler
public Action Command_Function(int iClient, int args)
{
    // Command logic
    return Plugin_Handled;
}
```

### Adding New Configuration Variables
```sourcepawn
// In OnPluginStart()
ConVar hNewCvar = CreateConVar("sm_vip_new_setting", "default", "Description");
hNewCvar.AddChangeHook(OnNewSettingChange);
g_iNewSetting = hNewCvar.IntValue;

// Change hook
public void OnNewSettingChange(ConVar hCvar, const char[] oldVal, const char[] newVal)
{
    g_iNewSetting = GetConVarInt(hCvar);
}
```

### Adding New Database Tables
```sourcepawn
// In CreateTables() function
if (g_bDBMySQL) {
    Format(sQuery, sizeof(sQuery), 
        "CREATE TABLE IF NOT EXISTS `new_table` ("
        "`id` INT AUTO_INCREMENT PRIMARY KEY, "
        "`data` VARCHAR(255)) "
        "DEFAULT CHARSET=%s COLLATE=%s;", 
        DB_CHARSET, DB_COLLATION);
} else {
    SQL_TQuery(g_hDatabase, SQL_Callback_ErrorCheck,
        "CREATE TABLE IF NOT EXISTS `new_table` ("
        "`id` INTEGER PRIMARY KEY AUTOINCREMENT, "
        "`data` VARCHAR(255));");
}
```

## Testing & Validation

### Manual Testing
1. Test on development server with both database types
2. Verify all console commands work correctly
3. Test translation files with different language settings
4. Validate database operations don't block server

### Code Validation
```bash
# Compile to check for syntax errors
spcomp VIP_Test.sp

# Check for common issues
# - Memory leaks (avoid .Clear(), use delete)
# - Synchronous database calls (all must be async)
# - Missing error handling in SQL callbacks
# - Hardcoded strings (should use translations)
```

## Performance Considerations

### Database Optimization
- Use LIMIT clauses in SELECT queries
- Index auth columns for faster lookups
- Minimize database queries in frequently called functions
- Use batch operations where possible

### Code Optimization
- Cache ConVar values instead of repeated GetConVarInt calls
- Avoid string operations in timer callbacks
- Use efficient data structures (StringMap for lookups)
- Consider the impact on server tick rate

## Security Considerations

### Input Validation
```sourcepawn
// Validate SteamID before database operations
if (!GetClientAuthId(iClient, AuthId_Steam2, sAuth, sizeof(sAuth), true)) {
    // Handle invalid SteamID
    return;
}
```

### SQL Injection Prevention
- Always use proper format strings
- Escape user input when necessary
- Use parameterized queries where supported
- Validate data types and ranges

## Common Pitfalls to Avoid

1. **Synchronous Database Calls**: Always use SQL_TQuery, never SQL_Query
2. **Memory Leaks**: Use `delete` instead of `.Clear()` for StringMaps/ArrayLists
3. **Missing Error Handling**: Always check for INVALID_HANDLE and errors in SQL callbacks
4. **Hardcoded Strings**: Use translation files for all user-facing messages
5. **Handle Cleanup**: Use `delete` for handles, no need to check for null first
6. **ConVar Access**: Cache values instead of repeated GetConVarInt calls in loops

## File Modification Guidelines

### When modifying VIP_Test.sp:
- Follow existing code style and patterns
- Add appropriate error handling for new database operations
- Update translation files if adding new user messages
- Test with both MySQL and SQLite configurations
- Ensure changes don't break existing VIP Core integration

### When adding new features:
- Consider database schema changes carefully
- Add appropriate configuration variables
- Implement admin commands if needed
- Add logging for important events
- Update documentation if changing behavior significantly

## Dependencies & External Resources

- **VIP Core Plugin**: Required dependency from srcdslab/sm-plugin-VIP-Core
- **SourceMod Include Files**: Automatically handled by SourceKnight
- **Database Configuration**: Uses "vip_test" section in databases.cfg or SQLite fallback
- **Translation Files**: Must be present in translations directory

This plugin is part of a larger VIP system ecosystem and should maintain compatibility with other VIP-related plugins.