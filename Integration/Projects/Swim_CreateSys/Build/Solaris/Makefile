PKG=CC-Apache-Conf

all:	pack

pack:
	( set +x ;\
	PKGNAME=${PKG} ;\
	PWD=`pwd` ;\
	SOURCEDIR=$${PWD} ;\
	mkdir -p ./$${PKGNAME}.tmp ;\
	/usr/bin/perl -pi -e s/X.X.X.X/$${VERSION}/g $${SOURCEDIR}/pkginfo ;\
	/usr/bin/perl -pi -e s/XX/$${BUILD}/g $${SOURCEDIR}/pkginfo ;\
	/usr/bin/pkgmk -d ./$${PKGNAME}.tmp -o -r $${SOURCEDIR} -f $${SOURCEDIR}/prototype ;\
	FULL_FILE=$${PKGNAME}-$${VERSION}.pkg ;\
	/usr/bin/pkgtrans -s ./$${PKGNAME}.tmp $${PWD}/kit/PKG/$${FULL_FILE} $${PKGNAME} ;\
	rm -rf ./$${PKGNAME}.tmp )
