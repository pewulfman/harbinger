if [ $# -ne 1 ]; then
	 echo "Usage: $0 <oracleData.csv>"
	 exit 1
fi

# Get the file name
file=$1

# Get the secret key from octez-client
sk=`octez-client show address wulfman -S | grep "edsk.*" | cut -d ":" -f 3`

# key value list of the map
map=()


# Read the CSV file
while IFS=, read -r key start end open high low close volume; do
	map+=("`./make_map_entry.sh $sk $key $start $end $open $high $low $close $volume`")
done < <(tail -n +2 $file)

# Make the map
map=$(IFS=";"; printf '%s' "${map[*]}")


# Make the update parameter
ligo compile parameter oracle.mligo "Update (Map.literal [$map])"
