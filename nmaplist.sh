#!/bin/bash

echo "Enter network to scan eg. 192.168.1.1/24"
read scannetwork
nmap $scannetwork -p22,80,443 --open -oG - | awk '
/^[0-9]+\/tcp/{                   ##Checking condition if line starts from digits then / and tcp then do following.
  sub(/\/.*/,"",$1)               ##Substituting from / till everything will NULL in 1st field.
  if(!tcpVal[$1]++){ a=""    }    ##Checking condition if $1 is NOT present in tcpVal array then place 
                                  ##it as an index in it and as a placeholder mentioning a to NULL.
}
/^[0-9]+\/udp/{                   ##Checking condition if line starts from digits / udp then do following.
  sub(/\/.*/,"",$1)               ##Substituting everything from / till last of line with NULL in $1.
  if(!udpVal[$1]++){ a=""    }    ##Checking condition if $1 is NOT present in udpVal array then place
                                  ##it as an index in it and as a placeholder mentioning a to NULL.
}
END{                              ##Starting END block of this specific awk program.
  print "U:"                      ##Printing U: here as per requested output.
  for(i in udpVal) { print i }    ##Traversing through array udpVal and printing index value(i).
  print "T:"                      ##Printing T: here as per requested output.
  for(j in tcpVal) { print j }    ##Traversing through array tcpVal and printing index value(i).
}'		                  ##Mentioning Input_file name here.
