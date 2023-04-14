if [ $# -ne 9 ]
then
	echo "Usage: $0 <sk> <key> <start> <end> <open> <high> <low> <close> <volume>"
	exit 1
fi

# Name the parameters
sk=$1
key=$2
start=$(date -Iseconds)
end=$(date -Iseconds)
open=$5
high=$6
low=$7
close=$8
volume=$9


#make oracleData
oracleData="{start = (\"$start\" : timestamp ); end_ = (\"$end\" : timestamp ); open = ${open}n; high = ${high}n; low = ${low}n; close = ${close}n; volume = ${volume}n}"

# Cipher the oracleData
cipheredOracleData=`ligo run test-expr cameligo --init oracle.mligo "Test.log (Test.sign \"$sk\" (Bytes.pack (\"$key\",$oracleData)))" | grep "edsig.*"`

# make map entry
mapEntry="(\"$key\",((\"$cipheredOracleData\" : signature), $oracleData))"

#print mapEntry
echo $mapEntry
