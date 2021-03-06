#!/bin/bash

dir="$PWD"
cd $(cd "$(dirname "$0")" ; pwd)/..


prodlike=''
if [ "${1}" == '--prodlike' ] ; then
	prodlike=true
	shift
fi

blog=''
if [ "${1}" == '--blog' ] ; then
	blog=true
	shift
fi

if [ "${prodlike}" ] ; then
	./commands/copyworkspace.sh .build
	cd .build
fi

eval "$(./commands/getgitdata.sh)"


appserver () {
	/google-cloud-sdk/bin/dev_appserver.py --skip_sdk_update_check ${*} > /dev/null 2>&1 &
}

go_appserver () {
	~/go_appengine/dev_appserver.py --skip_sdk_update_check ${*} &
}


for project in cyph.com cyph.im ; do
	cd ${project}
	for d in $(ls ../shared) ; do
		rm -rf ${d} 2> /dev/null
		ln -s ../shared/${d} ${d}
		if ! grep ${d} .gitignore > /dev/null 2>&1 ; then
			{ cat .gitignore 2> /dev/null; echo ${d}; } | sort > .gitignore.new
			mv .gitignore.new .gitignore
			chmod 700 .gitignore
		fi
	done
	sudo umount js lib 2> /dev/null
	rm -rf js lib
	mkdir -p js lib/js
	cd js
	for d in $(ls ../../shared/js | grep -v node_modules) ; do
		ln -s ../../shared/js/${d} ${d}
	done
	ln -s /node_modules node_modules
	cd ../lib/js
	ln -s /node_modules node_modules
	cp ../../../shared/lib/js/base.js base.js
	cd ../../..
done

node /node_modules/.bin/firebase-server -p 44000 &

if [ "${blog}" ] ; then
	cd cyph.com
	rm -rf blog 2> /dev/null
	mkdir blog
	cd blog
	../../commands/wpstatic.sh http://localhost:42001/blog > /dev/null 2>&1 &
	cd ../..
fi

cp -f default/app.yaml default/.build.yaml
cp -f cyph.com/cyph-com.yaml cyph.com/.build.yaml
cp -f cyph.im/cyph-im.yaml cyph.im/.build.yaml

for f in */.build.yaml ; do sed -i 's|index.html|.index.html|g' $f ; done

cat ~/.cyph/default.vars >> default/.build.yaml
if [ "${branch}" == 'prod' ] ; then
	echo '  PROD: true' >> default/.build.yaml
	cat ~/.cyph/braintree.prod >> default/.build.yaml
else
	cat ~/.cyph/braintree.sandbox >> default/.build.yaml
fi

mkdir /tmp/cyph0;
go_appserver --port 5000 --admin_port 6000 --host 0.0.0.0 --storage_path /tmp/cyph0 default/.build.yaml;

{
	while [ ! -f ~/.initialbuild.done ] ; do sleep 1 ; done;

	mkdir /tmp/cyph1;
	appserver --port 5001 --admin_port 6001 --host 0.0.0.0 --storage_path /tmp/cyph1 cyph.com/.build.yaml;

	mkdir /tmp/cyph2;
	appserver --port 5002 --admin_port 6002 --host 0.0.0.0 --storage_path /tmp/cyph2 cyph.im/.build.yaml;
} &

if [ "${prodlike}" ] ; then
	start="$(date +%s)"
	./commands/build.sh --prod

	if (( $? )) ; then
		echo -e '\n\nBuild failed\n'
		exit 1
	fi

	cd shared
	find js -name '*.js' | xargs -I% ../commands/websign/threadpack.ts %
	cd ..

	echo -e "\n\n\nLocal env ready ($(expr $(date +%s) - $start)s)\n\n"
	sleep infinity
else
	# bash -c 'sleep 90 ; ./commands/docs.sh > /dev/null 2>&1' &
	./commands/build.sh --watch
fi

trap 'jobs -p | xargs kill' EXIT
