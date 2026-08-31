-- Only the newly mounted installer window is changed. No user preferences or
-- other Finder windows are touched. All geometry comes from build-dmg.sh.
on run arguments
    set volumeName to item 1 of arguments
    set windowWidth to (item 2 of arguments) as integer
    set windowHeight to (item 3 of arguments) as integer
    set appX to (item 4 of arguments) as integer
    set applicationsX to (item 5 of arguments) as integer
    set iconY to (item 6 of arguments) as integer
    tell application "Finder"
        tell disk volumeName
            open
            tell container window
                set current view to icon view
                set toolbar visible to false
                set statusbar visible to false
                set bounds to {160, 160, 160 + windowWidth, 160 + windowHeight}
            end tell
            set options to icon view options of container window
            set arrangement of options to not arranged
            set icon size of options to 112
            set text size of options to 14
            set background picture of options to file ".background:background.png"
            set position of item "QuilNode.app" to {appX, iconY}
            set position of item "Applications" to {applicationsX, iconY}
            set extension hidden of item "QuilNode.app" to true
            close
            open
            delay 1
            set bounds of container window to {160, 160, 160 + windowWidth, 160 + windowHeight}
            update without registering applications
            delay 2
            close
        end tell
    end tell
end run
