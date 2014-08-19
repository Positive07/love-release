# Android debug package
init_module "Android"


# Options
activity_defined_argument=false
package_name_defined_argument=false
while getoptex "$SCRIPT_ARGS" "$@"
do
    if [ "$OPTOPT" = "activity" ]; then
        ACTIVITY=$OPTARG
        activity_defined_argument=true
    elif [ "$OPTOPT" = "package-version" ]; then
        PACKAGE_VERSION=$OPTARG
    elif [ "$OPTOPT" = "maintainer-name" ]; then
        MAINTAINER_NAME=$OPTARG
    elif [ "$OPTOPT" = "package-name" ]; then
        PACKAGE_NAME=$OPTARG
        package_name_defined_argument=true
    elif [ "$OPTOPT" = "update-android" ]; then
        UPDATE_ANDROID_REPO=true
    fi
done
if [ "$package_name_defined_argument" = false ]; then
    PACKAGE_NAME=$(echo $PROJECT_NAME | sed -e 's/[^-a-zA-Z0-9_]/-/g')
fi
if [ "$activity_defined_argument" = false ]; then
    ACTIVITY=$(echo $PROJECT_NAME | sed -e 's/[^a-zA-Z0-9_]/_/g')
fi


create_love_file


# Android
MISSING_INFO=0
ERROR_MSG="Could not build Android package."
if [ -z "$PACKAGE_VERSION" ]; then
    MISSING_INFO=1
    ERROR_MSG="$ERROR_MSG
    Missing project's version. Use --package-version."
fi
if [ -z "$MAINTAINER_NAME" ]; then
    MISSING_INFO=1
    ERROR_MSG="$ERROR_MSG
    Missing maintainer's name. Use --maintainer-name."
fi
if [ "$MISSING_INFO" -eq 1  ]; then
    exit_module "$MISSING_INFO" "$ERROR_MSG"
fi

LOVE_ANDROID_DIR="$CACHE_DIR"/love-android-sdl2
if [ -d "$LOVE_ANDROID_DIR" ]; then
    cd "$LOVE_ANDROID_DIR"
    git checkout -- .
    rm -rf src/com bin gen
    if [ "$UPDATE_ANDROID_REPO" = true ]; then
        LOCAL=$(git rev-parse @)
        REMOTE=$(git rev-parse @{u})
        BASE=$(git merge-base @ @{u})
        if [ $LOCAL = $REMOTE ]; then
            echo "love-android-sdl2 is already up-to-date."
        elif [ $LOCAL = $BASE ]; then
            git pull
            ndk-build --jobs $(( $(nproc) + 1))
        fi
    fi
    cd "$RELEASE_DIR"
else
    cd "$CACHE_DIR"
    git clone https://bitbucket.org/MartinFelis/love-android-sdl2.git
    cd "$LOVE_ANDROID_DIR"
    ndk-build --jobs $(( $(nproc) + 1))
    cd "$RELEASE_DIR"
fi

ANDROID_VERSION=$(grep -Eo -m 1 "[0-9]+.[0-9]+.[0-9]+[a-z]*" "$LOVE_ANDROID_DIR"/AndroidManifest.xml)
ANDROID_LOVE_VERSION=$(echo "$ANDROID_VERSION" | grep -Eo "[0-9]+.[0-9]+.[0-9]+")

if [ "$LOVE_VERSION" != "$ANDROID_LOVE_VERSION" ]; then
    echo "Love version ($LOVE_VERSION) differs from love-android-sdl2 version ($ANDROID_LOVE_VERSION). Could not create package."

else
    mkdir -p "$LOVE_ANDROID_DIR"/assets
    cp "$LOVE_FILE" "$LOVE_ANDROID_DIR"/assets/game.love
    cd "$LOVE_ANDROID_DIR"
    sed -i "s/org.love2d.android/com.${MAINTAINER_NAME}.${PACKAGE_NAME}/" AndroidManifest.xml
    sed -i "s/$ANDROID_VERSION/${ANDROID_VERSION}-${PACKAGE_NAME}-v${PACKAGE_VERSION}/" AndroidManifest.xml
    sed -i "0,/LÖVE for Android/s//$PROJECT_NAME $PACKAGE_VERSION/" AndroidManifest.xml
    sed -i "s/LÖVE for Android/$PROJECT_NAME/" AndroidManifest.xml
    sed -i "s/GameActivity/$ACTIVITY/" AndroidManifest.xml

    mkdir -p src/com/$MAINTAINER_NAME/$PACKAGE_NAME
    echo "package com.${MAINTAINER_NAME}.${PACKAGE_NAME};
    import org.love2d.android.GameActivity;

    public class $ACTIVITY extends GameActivity {}
    " > src/com/$MAINTAINER_NAME/$PACKAGE_NAME/${ACTIVITY}.java

    ant debug
    cp bin/love_android_sdl2-debug.apk "$RELEASE_DIR"
    cd "$RELEASE_DIR"
fi


remove_love_file
exit_module

