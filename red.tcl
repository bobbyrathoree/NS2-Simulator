#create a new simulator
set ns [new Simulator]

#get argument drr, fq or red
set qtype [lindex $argv 0]
#get simulation duration
set simTime [lindex $argv 1]
if {$simTime < 1} {
	set simTime 14.4
}
#get cwnd size if modifying for all
set cwndsiz [lindex $argv 2]

#Files for comparison
set winSizeVsTime [open timewin$qtype$simTime$cwndsiz w]
puts $winSizeVsTime "# time congestion window sizes of src 1 to n"
puts $winSizeVsTime "# time cwndsrc1 cwndsrc2 ..."

#opening NAM trace file
set nf [open out.nam w]
$ns namtrace-all $nf

#defining a finish procedure
proc finish {} {
	global ns nf numSrc
	$ns flush-trace
	#close the nam trace file
	close $nf
	exit 0
}

#create the tcp/ftp src nodes
set numSrc 4

#color them
$ns color 1 Red
$ns color 2 SeaGreen
$ns color 3 Yellow
$ns color 4 Blue

#create the basic 3 backbone nodes
set n0 [$ns node]
set n1 [$ns node]
set n2 [$ns node]

#$ns duplex-link $n0 $n1 15Mb 3ms DRR
$ns duplex-link $n0 $n1 15Mb 3ms $qtype
$ns duplex-link $n1 $n2 20Mb 25ms DropTail

#give position for the link on nam
$ns duplex-link-op $n0 $n1 orient right
$ns duplex-link-op $n1 $n2 orient right

#set monitors for link between n0, n1 and n2 for nam
$ns duplex-link-op $n0 $n1 queuePos 0.5
$ns duplex-link-op $n1 $n2 queuePos 0.5

#set queuesize : tried 400, 100 and 10k
#$ns queue-limit $n0 $n1 10000
#$ns queue-limit $n1 $n2 10000
$ns queue-limit $n0 $n1 200
$ns queue-limit $n1 $n2 200

#monitor and trace the queues for comparison
set qmon [$ns monitor-queue $n0 $n1 [open redq.tr w] 0.03];
[$ns link $n0 $n1] queue-sample-timeout; 
#monitor other queue
set qmon2 [$ns monitor-queue $n1 $n2 [open redq2.tr w] 0.03];
[$ns link $n1 $n2] queue-sample-timeout; 

#set redq [[$ns link $n0 $n1] queue]
#set traceq [open red-queue.tr w]
#$redq trace curq_
#$redq trace ave_
##$redq attach $traceq
#puts $traceq "$redq"

#link the 4 source nodes to n0
#for {set i 1} {$i<=$numSrc} { incr i } {
#    #create the node
#    set S($i) [$ns node]
#    #connect it to n0
#    $ns duplex-link $S($i) $n0 [expr $i * 2]Mb 1ms DropTail 
#    $ns queue-limit $S($i) $n0 10
#}

#Create the 4 tcp agents and ftp sources
for {set i 1} {$i<=$numSrc} {incr i} {
    set tcpsrc($i) [new Agent/TCP]

   $ns attach-agent $n0 $tcpsrc($i) 
    $tcpsrc($i) set class_ 2
    if {$cwndsiz > 10} {
		$tcpsrc($i) set window_ $cwndsiz
    } else {

    	if {$i == 1} {
#		    $tcpsrc($i) set packetSize_ 81
		    $tcpsrc($i) set window_ 9
    	}
    	if {$i == 2} {
#		    $tcpsrc($i) set packetSize_ 164
		    $tcpsrc($i) set window_ 18
    	}
    	if {$i == 3} {
#		    $tcpsrc($i) set packetSize_ 248
		    $tcpsrc($i) set window_ 45
	}
    	if {$i == 4} {
#		    $tcpsrc($i) set packetSize_ 335
		    $tcpsrc($i) set window_ 60
    	}
    }

    #create sink and connect src, sink and node
    set tcpsink($i) [new Agent/TCPSink]
    $ns attach-agent $n2 $tcpsink($i)
    $ns connect $tcpsrc($i) $tcpsink($i)
    $tcpsrc($i) set fid_ $i

    #create the ftp sources over tcp
    set ftp($i) [new Application/FTP]
    $ftp($i) attach-agent $tcpsrc($i)
    $ftp($i) set type_ FTP
}

proc plotWinTime {tcpSource file k} {
global ns numSrc
set time 0.03
set now [$ns now]
set cwnd [$tcpSource set cwnd_]
if {$k == 1} {
   puts -nonewline $file "$now \t $cwnd \t" 
  } else { 
   if {$k < $numSrc } { 
   puts -nonewline $file "$cwnd \t" } 
}
if { $k == $numSrc } {
   puts -nonewline $file "$cwnd \n" }
$ns at [expr $now+$time] "plotWinTime $tcpSource $file $k" }

# The procedure will now be called for all tcp sources
for {set j 1} {$j<=$numSrc} { incr j } {
$ns at 0.1 "plotWinTime $tcpsrc($j) $winSizeVsTime $j" 
}

#compute throughputs
proc calc_throughput {tcpsrc srcno simT} {

		set totpkts [$tcpsrc set ndatapack_]
		set pktsiz [$tcpsrc set packetSize_]
		set totsntsrc [$tcpsrc set ndatabytes_]
		set totretsrc [$tcpsrc set nrexmitbytes_]
		set throughput [expr [expr $totsntsrc - $totretsrc]*8.0/$simT/1024/1024]
		puts " Source $srcno: Number of packets Gen: $totpkts, Pkt size: $pktsiz B Throughput : $throughput Mbps"

}

for {set j 1} {$j<=$numSrc} {incr j} {
    $ns at 0.0 "$ftp($j) start"
s
    $ns at $simTime "$ftp($j) stop"
    $ns at $simTime "calc_throughput $tcpsrc($j) $j $simTime"
}

#detach tcp and sink agents - not nece

#call finish after 5secs
$ns at $simTime "finish"

#Run the simulation
$ns run
