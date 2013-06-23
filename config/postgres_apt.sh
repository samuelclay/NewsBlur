#!/bin/sh

# script to add apt.postgresql.org to sources.list

# from command like
CODENAME="$1"
# lsb_release is the best interface, but not always available
if [ -z "$CODENAME" ]; then
    CODENAME=$(lsb_release -cs 2>/dev/null)
fi
# parse os-release (unreliable, does not work on Ubuntu)
if [ -z "$CODENAME" -a -f /etc/os-release ]; then
    . /etc/os-release
    # Debian: VERSION="7.0 (wheezy)"
    # Ubuntu: VERSION="13.04, Raring Ringtail"
    CODENAME=$(echo $VERSION | sed -ne 's/.*(\(.*\)).*/\1/')
fi
# guess from sources.list
if [ -z "$CODENAME" ]; then
    CODENAME=$(grep '^deb ' /etc/apt/sources.list | head -n1 | awk '{ print $3 }')
fi
# complain if no result yet
if [ -z "$CODENAME" ]; then
    cat <<EOF
Could not determine the distribution codename. Please report this as a bug to
pgsql-pkg-debian@postgresql.org. As a workaround, you can call this script with
the proper codename as parameter, e.g. "$0 squeeze".
EOF
    exit 1
fi

# errors are non-fatal above
set -e

cat <<EOF
This script will enable the PostgreSQL APT repository on apt.postgresql.org on
your system. The distribution codename used will be $CODENAME-pgdg.

EOF

case $CODENAME in
    # known distributions
    sid|wheezy|squeeze|lenny|etch) ;;
    precise|lucid) ;;
    *) # unknown distribution, verify on the web
	DISTURL="http://apt.postgresql.org/pub/repos/apt/dists/"
	if [ -x /usr/bin/curl ]; then
	    DISTHTML=$(curl -s $DISTURL)
	elif [ -x /usr/bin/wget ]; then
	    DISTHTML=$(wget --quiet -O - $DISTURL)
	fi
	if [ "$DISTHTML" ]; then
	    if ! echo "$DISTHTML" | grep -q "$CODENAME-pgdg"; then
		cat <<EOF
Your system is using the distribution codename $CODENAME, but $CODENAME-pgdg
does not seem to be a valid distribution on
$DISTURL

We abort the installation here. Please ask on the mailing list for assistance.

pgsql-pkg-debian@postgresql.org
EOF
		exit 1
	    fi
	fi
	;;
esac

echo -n "Press Enter to continue, or Ctrl-C to abort."

read enter

echo "Writing /etc/apt/sources.list.d/pgdg.list ..."
cat > /etc/apt/sources.list.d/pgdg.list <<EOF
deb http://apt.postgresql.org/pub/repos/apt/ $CODENAME-pgdg main
#deb-src http://apt.postgresql.org/pub/repos/apt/ $CODENAME-pgdg main
EOF

echo "Importing repository signing key ..."
KEYRING="/etc/apt/trusted.gpg.d/apt.postgresql.org.gpg"
test -e $KEYRING || touch $KEYRING
apt-key --keyring $KEYRING add - <<EOF
-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG v1.4.12 (GNU/Linux)

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
VPZ67j5UMxqtT/Y4+NHcQGgwF/1i
=Iugu
-----END PGP PUBLIC KEY BLOCK-----
EOF

echo "Running apt-get update ..."
apt-get update

cat <<EOF

You can now start installing packages from apt.postgresql.org.

Have a look at https://wiki.postgresql.org/wiki/Apt for more information;
most notably the FAQ at https://wiki.postgresql.org/wiki/Apt/FAQ
EOF
