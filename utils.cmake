#[[
  MIT License

  Copyright (C) 2021-2023 by wangwenx190 (Yuhang Zhao)

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
]]

function(setup_project)
    cmake_parse_arguments(PROJ_ARGS "QT_PROJECT;ENABLE_LTO" "QML_IMPORT_DIR" "LANGUAGES" ${ARGN})
    if(NOT PROJ_ARGS_LANGUAGES)
        message(AUTHOR_WARNING "setup_project: You need to specify at least one language for this function!")
        return()
    endif()
    if(NOT DEFINED CMAKE_BUILD_TYPE)
        set(CMAKE_BUILD_TYPE Release PARENT_SCOPE)
    endif()
    if(NOT DEFINED CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE)
        # MinGW has many bugs when LTO is enabled, and they are all very
        # hard to workaround, so just don't enable LTO at all for MinGW.
        if(NOT MINGW AND PROJ_ARGS_ENABLE_LTO)
            set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE ON PARENT_SCOPE)
        endif()
    endif()
    if(NOT DEFINED CMAKE_DEBUG_POSTFIX)
        if(WIN32)
            set(CMAKE_DEBUG_POSTFIX d PARENT_SCOPE)
        else()
            set(CMAKE_DEBUG_POSTFIX _debug PARENT_SCOPE)
        endif()
    endif()
    if(NOT DEFINED CMAKE_RUNTIME_OUTPUT_DIRECTORY)
        set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/bin" PARENT_SCOPE)
    endif()
    if(NOT DEFINED CMAKE_LIBRARY_OUTPUT_DIRECTORY)
        set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/lib" PARENT_SCOPE)
    endif()
    if(NOT DEFINED CMAKE_ARCHIVE_OUTPUT_DIRECTORY)
        set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/lib" PARENT_SCOPE)
    endif()
    set(CMAKE_INCLUDE_CURRENT_DIR ON PARENT_SCOPE)
    foreach(__lang ${PROJ_ARGS_LANGUAGES})
        if(__lang STREQUAL "C")
            enable_language(C)
            if(NOT DEFINED CMAKE_C_STANDARD)
                set(CMAKE_C_STANDARD 11 PARENT_SCOPE)
            endif()
            set(CMAKE_C_STANDARD_REQUIRED ON PARENT_SCOPE)
            set(CMAKE_C_EXTENSIONS OFF PARENT_SCOPE)
            set(CMAKE_C_VISIBILITY_PRESET hidden PARENT_SCOPE)
        elseif(__lang STREQUAL "CXX")
            enable_language(CXX)
            if(NOT DEFINED CMAKE_CXX_STANDARD)
                set(CMAKE_CXX_STANDARD 20 PARENT_SCOPE)
            endif()
            set(CMAKE_CXX_STANDARD_REQUIRED ON PARENT_SCOPE)
            set(CMAKE_CXX_EXTENSIONS OFF PARENT_SCOPE)
            set(CMAKE_CXX_VISIBILITY_PRESET hidden PARENT_SCOPE)
            if(MSVC)
                string(REGEX REPLACE "[-|/]GR-? " " " CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS})
                string(REGEX REPLACE "[-|/]EHs-?c-? " " " CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS})
                string(REGEX REPLACE "[-|/]W[0|1|2|3|4|all] " " " CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS})
                string(APPEND CMAKE_CXX_FLAGS " /GR /EHsc /W4 ")
                set(CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS} PARENT_SCOPE)
                if(MSVC_VERSION GREATER_EQUAL 1920) # Visual Studio 2019 version 16.0
                    string(REGEX REPLACE "[-|/]Ob[0|1|2|3] " " " CMAKE_CXX_FLAGS_RELEASE ${CMAKE_CXX_FLAGS_RELEASE})
                    string(APPEND CMAKE_CXX_FLAGS_RELEASE " /Ob3 ")
                    set(CMAKE_CXX_FLAGS_RELEASE ${CMAKE_CXX_FLAGS_RELEASE} PARENT_SCOPE)
                endif()
            endif()
        elseif(__lang STREQUAL "RC")
            if(WIN32)
                enable_language(RC)
            endif()
            if(MSVC)
                set(CMAKE_RC_FLAGS "/c65001 /DWIN32 /nologo" PARENT_SCOPE)
            endif()
        endif()
    endforeach()
    set(CMAKE_POSITION_INDEPENDENT_CODE ON PARENT_SCOPE)
    set(CMAKE_VISIBILITY_INLINES_HIDDEN ON PARENT_SCOPE)
    if(PROJ_ARGS_QT_PROJECT)
        set(CMAKE_AUTOUIC ON PARENT_SCOPE)
        set(CMAKE_AUTOMOC ON PARENT_SCOPE)
        set(CMAKE_AUTORCC ON PARENT_SCOPE)
    endif()
    if(PROJ_ARGS_QML_IMPORT_DIR)
        list(APPEND QML_IMPORT_PATH "${PROJ_ARGS_QML_IMPORT_DIR}")
        list(REMOVE_DUPLICATES QML_IMPORT_PATH)
        set(QML_IMPORT_PATH ${QML_IMPORT_PATH} CACHE STRING "Qt Creator extra QML import paths" FORCE)
    endif()
endfunction()

function(get_commit_hash)
    cmake_parse_arguments(GIT_ARGS "" "RESULT" "" ${ARGN})
    if(NOT GIT_ARGS_RESULT)
        message(AUTHOR_WARNING "get_commit_hash: You need to specify a result variable for this function!")
        return()
    endif()
    set(__hash)
    # We do not want to use git command here because we don't want to make git a build-time dependency.
    if(EXISTS "${PROJECT_SOURCE_DIR}/.git/HEAD")
        file(READ "${PROJECT_SOURCE_DIR}/.git/HEAD" __hash)
        string(STRIP "${__hash}" __hash)
        if(__hash MATCHES "^ref: (.*)")
            set(HEAD "${CMAKE_MATCH_1}")
            if(EXISTS "${PROJECT_SOURCE_DIR}/.git/${HEAD}")
                file(READ "${PROJECT_SOURCE_DIR}/.git/${HEAD}" __hash)
                string(STRIP "${__hash}" __hash)
            else()
                file(READ "${PROJECT_SOURCE_DIR}/.git/packed-refs" PACKED_REFS)
                string(REGEX REPLACE ".*\n([0-9a-f]+) ${HEAD}\n.*" "\\1" __hash "\n${PACKED_REFS}")
            endif()
        endif()
    endif()
    if(__hash)
        set(${GIT_ARGS_RESULT} "${__hash}" PARENT_SCOPE)
    endif()
endfunction()

function(setup_qt_stuff)
    cmake_parse_arguments(QT_ARGS "ALLOW_KEYWORD" "" "TARGETS" ${ARGN})
    if(NOT QT_ARGS_TARGETS)
        message(AUTHOR_WARNING "setup_qt_stuff: You need to specify at least one target for this function!")
        return()
    endif()
    foreach(__target ${QT_ARGS_TARGETS})
        target_compile_definitions(${__target} PRIVATE
            QT_NO_CAST_TO_ASCII
            QT_NO_CAST_FROM_ASCII
            QT_NO_CAST_FROM_BYTEARRAY
            QT_NO_URL_CAST_FROM_STRING
            QT_NO_NARROWING_CONVERSIONS_IN_CONNECT
            QT_NO_FOREACH
            QT_NO_JAVA_STYLE_ITERATORS
            QT_NO_AS_CONST
            QT_NO_QEXCHANGE
            QT_EXPLICIT_QFILE_CONSTRUCTION_FROM_PATH
            #QT_TYPESAFE_FLAGS # QtQuick private headers prevent us from enabling this flag.
            QT_USE_QSTRINGBUILDER
            QT_USE_FAST_OPERATOR_PLUS
            QT_DEPRECATED_WARNINGS # Have no effect since 6.0
            QT_DEPRECATED_WARNINGS_SINCE=0x070000 # Deprecated since 6.5
            QT_WARN_DEPRECATED_UP_TO=0x070000 # Available since 6.5
            QT_DISABLE_DEPRECATED_BEFORE=0x070000 # Deprecated since 6.5
            QT_DISABLE_DEPRECATED_UP_TO=0x070000 # Available since 6.5
        )
        # On Windows enabling this flag requires us re-compile Qt with this flag enabled,
        # so only enable it on non-Windows platforms.
        target_compile_definitions(${__target} PRIVATE
            QT_STRICT_ITERATORS
        )
        # We handle this flag specially because some Qt headers may still use the
        # traditional keywords (especially some private headers).
        if(NOT QT_ARGS_ALLOW_KEYWORD)
            target_compile_definitions(${__target} PRIVATE
                QT_NO_KEYWORDS
            )
        endif()
    endforeach()
endfunction()

function(setup_compile_params)
    cmake_parse_arguments(COM_ARGS "SPECTRE;EHCONT;PERMISSIVE" "" "TARGETS" ${ARGN})
    if(NOT COM_ARGS_TARGETS)
        message(AUTHOR_WARNING "setup_compile_params: You need to specify at least one target for this function!")
        return()
    endif()
    foreach(__target ${COM_ARGS_TARGETS})
        # Needed by both MSVC and MinGW, otherwise some APIs we need will not be available.
        if(WIN32)
            set(_WIN32_WINNT_WIN10 0x0A00)
            set(NTDDI_WIN10_NI 0x0A00000C)
            # According to MS docs, both "WINVER" and "_WIN32_WINNT" should be defined
            # at the same time and they should use exactly the same value.
            target_compile_definitions(${__target} PRIVATE
                WINVER=${_WIN32_WINNT_WIN10} _WIN32_WINNT=${_WIN32_WINNT_WIN10}
                _WIN32_IE=${_WIN32_WINNT_WIN10} NTDDI_VERSION=${NTDDI_WIN10_NI}
            )
        endif()
        if(MSVC)
            target_compile_definitions(${__target} PRIVATE
                _CRT_NON_CONFORMING_SWPRINTFS _CRT_SECURE_NO_WARNINGS
                _CRT_SECURE_NO_DEPRECATE _CRT_NONSTDC_NO_WARNINGS
                _CRT_NONSTDC_NO_DEPRECATE _SCL_SECURE_NO_WARNINGS
                _SCL_SECURE_NO_DEPRECATE _ENABLE_EXTENDED_ALIGNED_STORAGE
                _USE_MATH_DEFINES NOMINMAX UNICODE _UNICODE
                WIN32_LEAN_AND_MEAN WINRT_LEAN_AND_MEAN
            )
            target_compile_options(${__target} PRIVATE
                /bigobj /utf-8 $<$<NOT:$<CONFIG:Debug>>:/fp:fast /GT /Gw /Gy /guard:cf /Zc:inline>
            )
            target_link_options(${__target} PRIVATE
                $<$<NOT:$<CONFIG:Debug>>:/OPT:REF /OPT:ICF /OPT:LBR /GUARD:CF>
                /DYNAMICBASE /NXCOMPAT /LARGEADDRESSAWARE /WX
            )
            set(__target_type "UNKNOWN")
            get_target_property(__target_type ${__target} TYPE)
            if(__target_type STREQUAL "EXECUTABLE")
                target_compile_options(${__target} PRIVATE $<$<NOT:$<CONFIG:Debug>>:/GA>)
                target_link_options(${__target} PRIVATE /TSAWARE)
            endif()
            if(CMAKE_SIZEOF_VOID_P EQUAL 4)
                target_link_options(${__target} PRIVATE /SAFESEH)
            endif()
            if(CMAKE_SIZEOF_VOID_P EQUAL 8)
                target_link_options(${__target} PRIVATE /HIGHENTROPYVA)
            endif()
            if(MSVC_VERSION GREATER_EQUAL 1915) # Visual Studio 2017 version 15.8
                target_compile_options(${__target} PRIVATE $<$<OR:$<CONFIG:Debug>,$<CONFIG:RelWithDebInfo>>:/JMC>)
            endif()
            if(MSVC_VERSION GREATER_EQUAL 1920) # Visual Studio 2019 version 16.0
                target_link_options(${__target} PRIVATE $<$<NOT:$<CONFIG:Debug>>:/CETCOMPAT>)
                if(CMAKE_SIZEOF_VOID_P EQUAL 8)
                    target_compile_options(${__target} PRIVATE /d2FH4)
                endif()
            endif()
            if(MSVC_VERSION GREATER_EQUAL 1925) # Visual Studio 2019 version 16.5
                target_compile_options(${__target} PRIVATE $<$<NOT:$<CONFIG:Debug>>:/QIntel-jcc-erratum>)
            endif()
            if(MSVC_VERSION GREATER_EQUAL 1929) # Visual Studio 2019 version 16.10
                target_compile_options(${__target} PRIVATE /await:strict)
            elseif(MSVC_VERSION GREATER_EQUAL 1900) # Visual Studio 2015
                target_compile_options(${__target} PRIVATE /await)
            endif()
            if(MSVC_VERSION GREATER_EQUAL 1930) # Visual Studio 2022 version 17.0
                target_compile_options(${__target} PRIVATE /options:strict)
            endif()
            if(COM_ARGS_SPECTRE)
                if(MSVC_VERSION GREATER_EQUAL 1925) # Visual Studio 2019 version 16.5
                    target_compile_options(${__target} PRIVATE /Qspectre-load)
                elseif(MSVC_VERSION GREATER_EQUAL 1912) # Visual Studio 2017 version 15.5
                    target_compile_options(${__target} PRIVATE /Qspectre)
                endif()
            endif()
            if(COM_ARGS_EHCONT)
                if((MSVC_VERSION GREATER_EQUAL 1927) AND (CMAKE_SIZEOF_VOID_P EQUAL 8)) # Visual Studio 2019 version 16.7
                    target_compile_options(${__target} PRIVATE $<$<NOT:$<CONFIG:Debug>>:/guard:ehcont>)
                    target_link_options(${__target} PRIVATE $<$<NOT:$<CONFIG:Debug>>:/guard:ehcont>)
                endif()
            endif()
            if(COM_ARGS_PERMISSIVE)
                target_compile_options(${__target} PRIVATE
                    /Zc:auto /Zc:forScope /Zc:implicitNoexcept /Zc:noexceptTypes /Zc:referenceBinding
                    /Zc:rvalueCast /Zc:sizedDealloc /Zc:strictStrings /Zc:throwingNew /Zc:trigraphs
                    /Zc:wchar_t
                )
                if(MSVC_VERSION GREATER_EQUAL 1900) # Visual Studio 2015
                    target_compile_options(${__target} PRIVATE /Zc:threadSafeInit)
                endif()
                if(MSVC_VERSION GREATER_EQUAL 1910) # Visual Studio 2017 version 15.0
                    target_compile_options(${__target} PRIVATE /permissive- /Zc:ternary)
                endif()
                if(MSVC_VERSION GREATER_EQUAL 1912) # Visual Studio 2017 version 15.5
                    target_compile_options(${__target} PRIVATE /Zc:alignedNew)
                endif()
                if(MSVC_VERSION GREATER_EQUAL 1913) # Visual Studio 2017 version 15.6
                    target_compile_options(${__target} PRIVATE /Zc:externConstexpr)
                endif()
                if(MSVC_VERSION GREATER_EQUAL 1914) # Visual Studio 2017 version 15.7
                    target_compile_options(${__target} PRIVATE /Zc:__cplusplus)
                endif()
                if(MSVC_VERSION GREATER_EQUAL 1921) # Visual Studio 2019 version 16.1
                    target_compile_options(${__target} PRIVATE /Zc:char8_t)
                endif()
                if(MSVC_VERSION GREATER_EQUAL 1923) # Visual Studio 2019 version 16.3
                    target_compile_options(${__target} PRIVATE /Zc:externC)
                endif()
                if(MSVC_VERSION GREATER_EQUAL 1924) # Visual Studio 2019 version 16.4
                    target_compile_options(${__target} PRIVATE /Zc:hiddenFriend)
                endif()
                if(MSVC_VERSION GREATER_EQUAL 1925) # Visual Studio 2019 version 16.5
                    target_compile_options(${__target} PRIVATE /Zc:preprocessor /Zc:tlsGuards)
                endif()
                if(MSVC_VERSION GREATER_EQUAL 1928) # Visual Studio 2019 version 16.8 & 16.9
                    target_compile_options(${__target} PRIVATE /Zc:lambda /Zc:zeroSizeArrayNew)
                endif()
                if(MSVC_VERSION GREATER_EQUAL 1931) # Visual Studio 2022 version 17.1
                    target_compile_options(${__target} PRIVATE /Zc:static_assert)
                endif()
                if(MSVC_VERSION GREATER_EQUAL 1932) # Visual Studio 2022 version 17.2
                    target_compile_options(${__target} PRIVATE /Zc:__STDC__)
                endif()
                if(MSVC_VERSION GREATER_EQUAL 1934) # Visual Studio 2022 version 17.4
                    target_compile_options(${__target} PRIVATE /Zc:enumTypes /Zc:gotoScope /Zc:nrvo)
                endif()
                if(MSVC_VERSION GREATER_EQUAL 1935) # Visual Studio 2022 version 17.5
                    target_compile_options(${__target} PRIVATE /Zc:templateScope /Zc:checkGwOdr)
                endif()
            endif()
        else()
            target_compile_options(${__target} PRIVATE
                -Wall -Wextra -Werror
                $<$<NOT:$<CONFIG:Debug>>:-ffunction-sections -fdata-sections> # -fcf-protection=full? -Wa,-mno-branches-within-32B-boundaries?
            )
            if(APPLE)
                target_link_options(${__target} PRIVATE
                    $<$<NOT:$<CONFIG:Debug>>:-Wl,-dead_strip>
                )
            else()
                target_link_options(${__target} PRIVATE
                    $<$<NOT:$<CONFIG:Debug>>:-Wl,--gc-sections>
                )
            endif()
            # TODO: spectre, control flow guard
        endif()
    endforeach()
endfunction()

function(setup_gui_app)
    # TODO: macOS bundle icon
    cmake_parse_arguments(GUI_ARGS "" "BUNDLE_ID;BUNDLE_VERSION;BUNDLE_VERSION_SHORT" "TARGETS" ${ARGN})
    if(NOT GUI_ARGS_TARGETS)
        message(AUTHOR_WARNING "setup_gui_app: You need to specify at least one target for this function!")
        return()
    endif()
    foreach(__target ${GUI_ARGS_TARGETS})
        set_target_properties(${__target} PROPERTIES
            WIN32_EXECUTABLE TRUE
            MACOSX_BUNDLE TRUE
        )
        if(GUI_ARGS_BUNDLE_ID)
            set_target_properties(${__target} PROPERTIES
                MACOSX_BUNDLE_GUI_IDENTIFIER ${GUI_ARGS_BUNDLE_ID}
            )
        endif()
        if(GUI_ARGS_BUNDLE_VERSION)
            set_target_properties(${__target} PROPERTIES
                MACOSX_BUNDLE_BUNDLE_VERSION ${GUI_ARGS_BUNDLE_VERSION}
            )
        endif()
        if(GUI_ARGS_BUNDLE_VERSION_SHORT)
            set_target_properties(${__target} PROPERTIES
                MACOSX_BUNDLE_SHORT_VERSION_STRING ${GUI_ARGS_BUNDLE_VERSION_SHORT}
            )
        endif()
    endforeach()
endfunction()

function(prepare_package_export)
    cmake_parse_arguments(PKG_ARGS "NO_INSTALL" "PACKAGE_NAME;PACKAGE_VERSION" "" ${ARGN})
    if(NOT PKG_ARGS_PACKAGE_NAME)
        message(AUTHOR_WARNING "prepare_package_export: You need to specify the package name for this function!")
        return()
    endif()
    if(NOT PKG_ARGS_PACKAGE_VERSION)
        message(AUTHOR_WARNING "prepare_package_export: You need to specify the package version for this function!")
        return()
    endif()
    include(CMakePackageConfigHelpers)
    include(GNUInstallDirs)
    write_basic_package_version_file(
        "${CMAKE_CURRENT_BINARY_DIR}/${PKG_ARGS_PACKAGE_NAME}ConfigVersion.cmake"
        VERSION ${PKG_ARGS_PACKAGE_VERSION}
        COMPATIBILITY AnyNewerVersion
    )
    configure_package_config_file("${CMAKE_CURRENT_SOURCE_DIR}/${PKG_ARGS_PACKAGE_NAME}Config.cmake.in"
        "${CMAKE_CURRENT_BINARY_DIR}/${PKG_ARGS_PACKAGE_NAME}Config.cmake"
        INSTALL_DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/${PKG_ARGS_PACKAGE_NAME}"
        NO_CHECK_REQUIRED_COMPONENTS_MACRO
    )
    if(NOT PKG_ARGS_NO_INSTALL)
        install(FILES
            "${CMAKE_CURRENT_BINARY_DIR}/${PKG_ARGS_PACKAGE_NAME}Config.cmake"
            "${CMAKE_CURRENT_BINARY_DIR}/${PKG_ARGS_PACKAGE_NAME}ConfigVersion.cmake"
            DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/${PKG_ARGS_PACKAGE_NAME}"
        )
    endif()
endfunction()

function(setup_package_export)
    cmake_parse_arguments(PKG_ARGS ""
        "TARGET;BIN_PATH;LIB_PATH;INCLUDE_PATH;NAMESPACE;PACKAGE_NAME"
        "PUBLIC_HEADERS;PRIVATE_HEADERS;ALIAS_HEADERS" ${ARGN})
    if(NOT PKG_ARGS_TARGET)
        message(AUTHOR_WARNING "setup_package_export: You need to specify a target for this function!")
        return()
    endif()
    if(NOT PKG_ARGS_NAMESPACE)
        message(AUTHOR_WARNING "setup_package_export: You need to specify an export namespace for this function!")
        return()
    endif()
    if(NOT PKG_ARGS_PACKAGE_NAME)
        message(AUTHOR_WARNING "setup_package_export: You need to specify a package name for this function!")
        return()
    endif()
    include(GNUInstallDirs)
    set(__targets ${PKG_ARGS_TARGET})
    # Ugly hack to workaround a CMake configure error.
    if(TARGET ${PKG_ARGS_TARGET}_resources_1)
        list(APPEND __targets ${PKG_ARGS_TARGET}_resources_1)
    endif()
    set(__bin_dir "${CMAKE_INSTALL_BINDIR}")
    if(PKG_ARGS_BIN_PATH)
        set(__bin_dir "${__bin_dir}/${PKG_ARGS_BIN_PATH}")
    endif()
    set(__lib_dir "${CMAKE_INSTALL_LIBDIR}")
    if(PKG_ARGS_LIB_PATH)
        set(__lib_dir "${__lib_dir}/${PKG_ARGS_LIB_PATH}")
    endif()
    set(__inc_dir "${CMAKE_INSTALL_INCLUDEDIR}")
    if(PKG_ARGS_INCLUDE_PATH)
        set(__inc_dir "${__inc_dir}/${PKG_ARGS_INCLUDE_PATH}")
    endif()
    install(TARGETS ${__targets}
        EXPORT ${PKG_ARGS_TARGET}Targets
        RUNTIME  DESTINATION "${__bin_dir}"
        LIBRARY  DESTINATION "${__lib_dir}"
        ARCHIVE  DESTINATION "${__lib_dir}"
        INCLUDES DESTINATION "${__inc_dir}"
    )
    export(EXPORT ${PKG_ARGS_TARGET}Targets
        FILE "${CMAKE_CURRENT_BINARY_DIR}/cmake/${PKG_ARGS_TARGET}Targets.cmake"
        NAMESPACE ${PKG_ARGS_NAMESPACE}::
    )
    if(PKG_ARGS_PUBLIC_HEADERS)
        install(FILES ${PKG_ARGS_PUBLIC_HEADERS} DESTINATION "${__inc_dir}")
    endif()
    if(PKG_ARGS_PRIVATE_HEADERS)
        install(FILES ${PKG_ARGS_PRIVATE_HEADERS} DESTINATION "${__inc_dir}/private")
    endif()
    if(PKG_ARGS_ALIAS_HEADERS)
        install(FILES ${PKG_ARGS_ALIAS_HEADERS} DESTINATION "${__inc_dir}")
    endif()
    install(EXPORT ${PKG_ARGS_TARGET}Targets
        FILE ${PKG_ARGS_TARGET}Targets.cmake
        NAMESPACE ${PKG_ARGS_NAMESPACE}::
        DESTINATION "${__lib_dir}/cmake/${PKG_ARGS_PACKAGE_NAME}"
    )
endfunction()

function(deploy_qt_runtime)
    cmake_parse_arguments(DEPLOY_ARGS "NO_INSTALL" "TARGET;QML_SOURCE_DIR;QML_IMPORT_DIR" "" ${ARGN})
    if(NOT DEPLOY_ARGS_TARGET)
        message(AUTHOR_WARNING "deploy_qt_runtime: You need to specify a target for this function!")
        return()
    endif()
    find_package(QT NAMES Qt6 Qt5 QUIET COMPONENTS Core)
    if(NOT (Qt5_FOUND OR Qt6_FOUND))
        message(AUTHOR_WARNING "deploy_qt_runtime: You need to install the QtCore module first to be able to deploy the Qt libraries.")
        return()
    endif()
    find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS Core)
    # "QT_QMAKE_EXECUTABLE" is usually defined by QtCreator.
    if(NOT DEFINED QT_QMAKE_EXECUTABLE)
        get_target_property(QT_QMAKE_EXECUTABLE Qt::qmake IMPORTED_LOCATION)
    endif()
    if(NOT EXISTS "${QT_QMAKE_EXECUTABLE}")
        message(WARNING "deploy_qt_runtime: Can't locate the QMake executable.")
        return()
    endif()
    get_filename_component(__qt_bin_dir "${QT_QMAKE_EXECUTABLE}" DIRECTORY)
    find_program(__deploy_tool NAMES windeployqt macdeployqt HINTS "${__qt_bin_dir}")
    if(NOT EXISTS "${__deploy_tool}")
        message(WARNING "deploy_qt_runtime: Can't locate the deployqt tool.")
        return()
    endif()
    set(__is_quick_app FALSE)
    if(WIN32)
        set(__old_deploy_params)
        if(QT_VERSION_MAJOR LESS 6)
            set(__old_deploy_params
                --no-webkit2
                #--no-angle
            )
        endif()
        set(__quick_deploy_params)
        if(DEPLOY_ARGS_QML_SOURCE_DIR)
            set(__is_quick_app TRUE)
            set(__quick_deploy_params
                --qmldir "${DEPLOY_ARGS_QML_SOURCE_DIR}"
            )
            if(QT_VERSION VERSION_GREATER_EQUAL "6.6") # FIXME
                set(__quick_deploy_params
                    ${__quick_deploy_params}
                    --qml-deploy-dir "$<TARGET_FILE_DIR:${DEPLOY_ARGS_TARGET}>/../qml"
                )
            else()
                set(__quick_deploy_params
                    ${__quick_deploy_params}
                    --dir "$<TARGET_FILE_DIR:${DEPLOY_ARGS_TARGET}>/../qml"
                )
            endif()
        endif()
        if(DEPLOY_ARGS_QML_IMPORT_DIR)
            set(__is_quick_app TRUE)
            set(__quick_deploy_params
                ${__quick_deploy_params}
                --qmlimport "${DEPLOY_ARGS_QML_IMPORT_DIR}"
            )
        endif()
        set(__extra_deploy_params)
        if(QT_VERSION VERSION_GREATER_EQUAL "6.6") # FIXME
            set(__extra_deploy_params
                --translationdir "$<TARGET_FILE_DIR:${DEPLOY_ARGS_TARGET}>/../translations"
            )
        endif()
        add_custom_command(TARGET ${DEPLOY_ARGS_TARGET} POST_BUILD COMMAND
            "${__deploy_tool}"
            $<$<CONFIG:Debug>:--debug>
            $<$<OR:$<CONFIG:MinSizeRel>,$<CONFIG:Release>,$<CONFIG:RelWithDebInfo>>:--release>
            --libdir "$<TARGET_FILE_DIR:${DEPLOY_ARGS_TARGET}>"
            --plugindir "$<TARGET_FILE_DIR:${DEPLOY_ARGS_TARGET}>/../plugins"
            #--no-translations
            #--no-system-d3d-compiler
            --no-virtualkeyboard
            --no-compiler-runtime
            #--no-opengl-sw
            --force
            #--verbose 0
            ${__quick_deploy_params}
            ${__old_deploy_params}
            ${__extra_deploy_params}
            "$<TARGET_FILE:${DEPLOY_ARGS_TARGET}>"
        )
    elseif(APPLE)
        set(__quick_deploy_params)
        if(DEPLOY_ARGS_QML_SOURCE_DIR)
            set(__is_quick_app TRUE)
            set(__quick_deploy_params
                -qmldir="${DEPLOY_ARGS_QML_SOURCE_DIR}"
            )
        endif()
        if(DEPLOY_ARGS_QML_IMPORT_DIR)
            set(__is_quick_app TRUE)
            set(__quick_deploy_params
                ${__quick_deploy_params}
                -qmlimport="${DEPLOY_ARGS_QML_IMPORT_DIR}"
            )
        endif()
        add_custom_command(TARGET ${DEPLOY_ARGS_TARGET} POST_BUILD COMMAND
            "${__deploy_tool}"
            "$<TARGET_BUNDLE_DIR:${DEPLOY_ARGS_TARGET}>"
            #-verbose=0
            ${__quick_deploy_params}
        )
    elseif(UNIX)
        # TODO
    endif()
    file(WRITE "$<TARGET_FILE_DIR:${DEPLOY_ARGS_TARGET}>/qt.conf" "[Paths]\nPrefix = ..\n")
    if(NOT DEPLOY_ARGS_NO_INSTALL)
        include(GNUInstallDirs)
        install(TARGETS ${DEPLOY_ARGS_TARGET}
            BUNDLE  DESTINATION .
            RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
        )
        if(QT_VERSION VERSION_GREATER_EQUAL "6.3")
            set(__deploy_script)
            if(${__is_quick_app})
                qt_generate_deploy_qml_app_script(
                    TARGET ${DEPLOY_ARGS_TARGET}
                    FILENAME_VARIABLE __deploy_script
                    #MACOS_BUNDLE_POST_BUILD
                    NO_UNSUPPORTED_PLATFORM_ERROR
                    DEPLOY_USER_QML_MODULES_ON_UNSUPPORTED_PLATFORM
                )
            else()
                qt_generate_deploy_app_script(
                    TARGET ${DEPLOY_ARGS_TARGET}
                    FILENAME_VARIABLE __deploy_script
                    NO_UNSUPPORTED_PLATFORM_ERROR
                )
            endif()
            install(SCRIPT "${__deploy_script}")
        endif()
    endif()
endfunction()

function(setup_translations)
    cmake_parse_arguments(TRANSLATION_ARGS "NO_INSTALL" "TARGET;TS_DIR;QM_DIR;INSTALL_DIR" "LOCALES" ${ARGN})
    if(NOT TRANSLATION_ARGS_TARGET)
        message(AUTHOR_WARNING "setup_translations: You need to specify a target for this function!")
        return()
    endif()
    if(NOT TRANSLATION_ARGS_LOCALES)
        message(AUTHOR_WARNING "setup_translations: You need to specify at least one locale for this function!")
        return()
    endif()
    # Qt5's CMake functions to create translations lack many features
    # we need and what's worse, they also have a severe bug which will
    # wipe out our .ts files' contents every time we call them, so we
    # really can't use them until Qt6 (the functions have been completely
    # re-written in Qt6 and according to my experiments they work reliably
    # now finally).
    find_package(Qt6 QUIET COMPONENTS LinguistTools)
    if(NOT Qt6LinguistTools_FOUND)
        message(AUTHOR_WARNING "setup_translations: You need to install the Qt Linguist Tools first to be able to create translations.")
        return()
    endif()
    set(__ts_dir translations)
    if(TRANSLATION_ARGS_TS_DIR)
        set(__ts_dir "${TRANSLATION_ARGS_TS_DIR}")
    endif()
    set(__qm_dir "${PROJECT_BINARY_DIR}/translations")
    if(TRANSLATION_ARGS_QM_DIR)
        set(__qm_dir "${TRANSLATION_ARGS_QM_DIR}")
    endif()
    set(__ts_files)
    foreach(__locale ${TRANSLATION_ARGS_LOCALES})
        list(APPEND __ts_files "${__ts_dir}/${TRANSLATION_ARGS_TARGET}_${__locale}.ts")
    endforeach()
    set_source_files_properties(${__ts_files} PROPERTIES
        OUTPUT_LOCATION "${__qm_dir}"
    )
    set(__qm_files)
    qt_add_translations(${TRANSLATION_ARGS_TARGET}
        TS_FILES ${__ts_files}
        QM_FILES_OUTPUT_VARIABLE __qm_files
        LUPDATE_OPTIONS
            -no-obsolete # Don't keep vanished translation contexts.
        LRELEASE_OPTIONS
            -compress # Compress the QM file if the file size can be decreased siginificantly.
            -nounfinished # Don't include unfinished translations (to save file size).
            -removeidentical # Don't include translations that are the same with their original texts (to save file size).
    )
    if(NOT TRANSLATION_ARGS_NO_INSTALL)
        set(__inst_dir translations)
        if(TRANSLATION_ARGS_INSTALL_DIR)
            set(__inst_dir "${TRANSLATION_ARGS_INSTALL_DIR}")
        endif()
        install(FILES ${__qm_files} DESTINATION "${__inst_dir}")
    endif()
endfunction()
