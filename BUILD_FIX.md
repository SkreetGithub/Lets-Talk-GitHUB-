# Build Fix Instructions

## Info.plist Duplicate Error Fix

If you encounter the error:
```
Multiple commands produce '/Users/.../Let Talk 3.0.app/Info.plist'
The Copy Bundle Resources build phase contains this target's Info.plist file
```

### Solution (Manual Fix in Xcode):

1. **Open Xcode** and open `Let Talk 3.0.xcodeproj`

2. **Select the Project** in the navigator (top item)

3. **Select the Target** "Let Talk 3.0"

4. **Go to Build Phases** tab

5. **Expand "Copy Bundle Resources"**

6. **Find and Remove** `Info.plist` from the list (if it appears)
   - Select it and click the **minus (-)** button
   - Info.plist should ONLY be processed via the `INFOPLIST_FILE` build setting, NOT as a resource

7. **Clean Build Folder**: Product → Clean Build Folder (Shift+Cmd+K)

8. **Build again**: Product → Build (Cmd+B)

### Why This Happens:

The project uses `PBXFileSystemSynchronizedRootGroup` which automatically includes all files in the "Let Talk 3.0" folder. Info.plist gets automatically added to Copy Bundle Resources, but it should only be processed via the `INFOPLIST_FILE` build setting.

### Alternative Solution:

If the manual removal doesn't work, you can:
1. Close Xcode
2. Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData/Let_Talk_3.0-*`
3. Reopen Xcode and try building again

