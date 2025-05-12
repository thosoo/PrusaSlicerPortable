!macro CustomCodePostInstall
    ${If} ${FileExists} "$INSTDIR\\App\\PrusaSlicer-2.9.2"
        Rename "$INSTDIR\\App\\PrusaSlicer-2.9.2" \
               "$INSTDIR\\App\\PrusaSlicer-2.9.2-win64"
    ${EndIf}
!macroend
