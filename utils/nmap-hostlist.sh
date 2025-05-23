NMAP_FILE=output.grep
egrep -v "^#|Status: Up" $NMAP_FILE | cut -d' ' -f2,4- | \
sed -n -e 's/Ignored.*//p'  | \
awk '
{
    print "Host: " $1 " Ports: " NF-1
    $1=""
    for (i=2; i<=NF; i++) {
        a = a " " $i
    }
    split(a, s, ",")
    for (e in s) {
        split(s[e], v, "/")
        printf "%-8s %s/%-7s %s\n", v[2], v[3], v[1], v[5]
    }
    a = ""
}'
