DEVELOPER_DIR=/Xcode3.2.6
PATH=${DEVELOPER_DIR}/usr/bin:/usr/bin:/bin
xcb=DEVELOPER_DIR=${DEVELOPER_DIR} xcodebuild

all:

build: clean
	${xcb} -sdk macosx10.4 -configuration Debug \
	ARCHS='i386 ppc' ONLY_ACTIVE_ARCH=NO MACOSX_DEPLOYMENT_TARGET=10.4 \
	GCC_VERSION=4.0
release:	build
	make -f ../mk/make-dmg.mk NAME=encode VERSION=1.0 \
		SOURCE_DIR=build/Debug SOURCE_FILES=Encoding.app
	


clean:
	${xcb} -configuration Debug clean
	${xcb} -configuration Release clean

