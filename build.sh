#!/bin/bash

set -x

CURRENT=`pwd`
__pr="--print-path"
__name="xcode-select"
DEVELOPER=`${__name} ${__pr}`

SDKVERSION=`xcrun -sdk iphoneos --show-sdk-version`

MIN_IOS="17.0"
MIN_MACOS="13.0"

BITCODE="-fembed-bitcode"

OSX_PLATFORM=`xcrun --sdk macosx --show-sdk-platform-path`
OSX_SDK=`xcrun --sdk macosx --show-sdk-path`

IPHONEOS_PLATFORM=`xcrun --sdk iphoneos --show-sdk-platform-path`
IPHONEOS_SDK=`xcrun --sdk iphoneos --show-sdk-path`

IPHONESIMULATOR_PLATFORM=`xcrun --sdk iphonesimulator --show-sdk-platform-path`
IPHONESIMULATOR_SDK=`xcrun --sdk iphonesimulator --show-sdk-path`

CLANG=`xcrun --sdk iphoneos --find clang`
CLANGPP=`xcrun --sdk iphoneos --find clang++`


build()
{
	ARCH=$1
	SDK=$2
	PLATFORM=$3
	COMPILEARGS=$4
	CONFIGUREARGS=$5

	make clean
	make distclean

	export PATH="${PLATFORM}/Developer/usr/bin:${DEVELOPER}/usr/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

	CFLAGS="${BITCODE} -isysroot ${SDK} -Wno-error -Wno-implicit-function-declaration -arch ${ARCH} ${COMPILEARGS}"

	./configure CC="${CLANG} ${CFLAGS}"  CPP="${CLANG} -E"  CPPFLAGS="${CFLAGS}" \
	--host=aarch64-apple-darwin --disable-assembly --enable-static --disable-shared ${CONFIGUREARGS}

	echo "make in progress for ${ARCH}"
	make &> "${CURRENT}/build.log"
}


rm -rf iPhone simulator mac
mkdir iPhone simulator mac

cd gmp
build "arm64" "${IPHONEOS_SDK}" "${IPHONEOS_PLATFORM}" "-mios-version-min=${MIN_IOS}"
cp .libs/libgmp.a ../iPhone/libgmp.a

build "arm64" "${IPHONESIMULATOR_SDK}" "${IPHONESIMULATOR_PLATFORM}" "-mios-simulator-version-min=${MIN_IOS}"
cp .libs/libgmp.a ../simulator/libgmp.a

build "arm64" "${OSX_SDK}" "${OSX_PLATFORM}" "-mmacosx-version-min=${MIN_MACOS}"
cp .libs/libgmp.a ../mac/libgmp.a
cd ..

pwd=`pwd`

cd mpfr
build "arm64" "${IPHONEOS_SDK}" "${IPHONEOS_PLATFORM}" "-mios-version-min=${MIN_IOS}" "--with-gmp-lib=${pwd}/iPhone --with-gmp-include=${pwd}/include"
cp src/.libs/libmpfr.a ../iPhone/libmpfr.a

build "arm64" "${IPHONESIMULATOR_SDK}" "${IPHONESIMULATOR_PLATFORM}" "-mios-simulator-version-min=${MIN_IOS}" "--with-gmp-lib=${pwd}/simulator --with-gmp-include=${pwd}/include"
cp src/.libs/libmpfr.a ../simulator/libmpfr.a

build "arm64" "${OSX_SDK}" "${OSX_PLATFORM}" "-mmacosx-version-min=${MIN_MACOS}" "--with-gmp-lib=${pwd}/mac --with-gmp-include=${pwd}/include"
cp src/.libs/libmpfr.a ../mac/libmpfr.a
cd ..

rm -rf signed
mkdir signed
cp -r iPhone simulator mac signed

# code signing: get the correct expanded identity with the command $security find-identity
identity='039E5E0C8815FFF5080702599A3C31A7212AA454'
codesign -s ${identity} signed/iPhone/libgmp.a
codesign -s ${identity} signed/simulator/libgmp.a
codesign -s ${identity} signed/mac/libgmp.a
codesign -s ${identity} signed/iPhone/libmpfr.a
codesign -s ${identity} signed/simulator/libmpfr.a
codesign -s ${identity} signed/mac/libmpfr.a

libtool -static -o signed/mac/libswiftgmp.a       signed/mac/libgmp.a       signed/mac/libmpfr.a
libtool -static -o signed/iPhone/libswiftgmp.a    signed/iPhone/libgmp.a    signed/iPhone/libmpfr.a
libtool -static -o signed/simulator/libswiftgmp.a signed/simulator/libgmp.a signed/simulator/libmpfr.a

rm -rf swiftgmp.xcframework
xcodebuild -create-xcframework \
-library signed/mac/libswiftgmp.a \
-headers include \
-library signed/iPhone/libswiftgmp.a \
-headers include \
-library signed/simulator/libswiftgmp.a \
-headers include \
-output swiftgmp.xcframework
