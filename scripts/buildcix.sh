#!/bin/sh

# create a message to be placed in vienna/files describing the file

# $1 = path to Vole command
# $2 = name of zip file
# $3 = name of file to write
# $4 = compatibility note
# $5 = status
# $6 = deployment target (10.4 10.5 etc)
# $7 = build archs (ppc i386 x86_64)
# $8 = SDK (macosx10.4 etc )

deploy="${6}"
archs="${7}"
sdk="${8}"

function list_minimum_osx(){
printf "Minumum OS X required: "
case ${deploy} in 
	10.4)   printf "10.4 Tiger and later";;
	10.5)   printf "10.5 Leopard and later";;
	10.6)   printf "10.6 Snow Leopard and later";;
	10.6.8) printf '10.6.8 Snow Leopard (last version) and later';;
	10.7)   printf "10.7 Lion and later";;
	10.8)   printf "10.8 Mountain Lion and later";;
        *         )  printf "Unknown";;
esac
}

function list_archs(){
printf "Runs On:"
native=No
for i in ${archs}
do
case $i in
	ppc)    ppc=" PowerPC" ;;
	i386)   i32=" Intel-32-bit" ; i64=" Intel-64-bit" ;;
	x86_64) i64=" Intel-64-bit" ; native=Yes ;;
esac
done
printf "%s%s%s\n" "${ppc}" "${i32}" "${i64}"
printf "Native Intel-64-bit: %s" $native
}
##### end of function #####

cat > $3  << XEOF
New file $2

[File]
Filename: $2
Hotlink to download: cixfile:vienna/files:$2
Size: $(wc -c $2 | awk '{printf $1}') 
$(/sbin/md5 $2)
$(openssl sha1 $2)

[Vole]
Description: Vole off-line reader for Mac OS X only
             Vole was formerly known as Vienna or Vinkix
Version: $($1 -m)
$(list_minimum_osx)
$(list_archs)
$5
Packaging: A zip file containing a disk image and an OpenPGP signature
SDK: ${sdk}
Checkout: $( $1 -c)
Build: $($1 -b)
$(dwarfdump --uuid $1 | awk '{ print $1, $2, $3 }')

[Built by]
Contributor: devans
Date: $(date '+%A %e %B %Y') 

[Warning]
***********************************************************************
To avoid disappointment and a wasted download, please check the 
Minimum OS X Required and Runs On fields above to make sure
that Vole will be compatible with your system.
 
Previous versions of Vole/Vinkix/Vienna were compatible with everything
from Tiger upwards. This is no longer the case.
***********************************************************************

[Notes]
$(/opt/local/bin/lynx -dump ../NOTES/RELEASE.html)

XEOF

