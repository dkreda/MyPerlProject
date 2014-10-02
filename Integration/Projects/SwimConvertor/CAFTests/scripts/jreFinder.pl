#!/usr/bin/perl
sub jreSet{
  if( -d "/usr/java"){
    $var=`ls /usr/java/`;
    $i=0;
    while($var =~ /jre([\d\.*_*]*)/)
    {
      $temp[$i]=$1;
      $i++;
      $var =~ s/$&//;
    }
    $max=$temp[$0];
    for ($j=0; $j<=$#temp; $j++){
	if($max lt $temp[$j]){
	$max=$temp[$j];}}
	$data="/usr/java/jre$max";
	if ($max lt 1.5){
          print "Error!!! Minimum JRE1.5 is supported\n";
          exit ;}
	`rm -f /usr/local/java`;
	`ln -fs $data /usr/local/java`;
	print "Link is created\n";
}
}

if( -d "/usr/java" ){
	print("Java is available\n");
	$java_executable="/usr/local/java/bin/java";
	$java_ver_file="/usr/tmp/java.ver";

	`$java_executable -version 2> $java_ver_file`;

	$java_installed=`cat $java_ver_file | head -1 |cut -d '"' -f2 | cut -d "." -f1-2`;
	`rm -rf $java_ver_file`;
	chomp($java_installed);
	if (($java_installed ge 1.5) && ($java_installed =~ /\d\.\d/)){
		 print "Babysitter is compatible with the jre $java_installed , which  is already installed. Exiting !!!!\n";
		 exit 0;
	}


	if( -d "/usr/local/java" ){
		$var=`ls -l /usr/local/java`;
		$var=~/jdk([\d\.]+)/;
		$tmp=$1;
		if($tmp){
			if( -d "/usr/java"){
			$var=`ls /usr/java/`;
			$i=0;
			while($var =~ /jdk([\d\.*_*]*)/)
			{
				$temp[$i]=$1;
				$i++;
				$var =~ s/$&//;
			}
		$max=$temp[$0];
		for ($j=0; $j<=$#temp; $j++){
		if($max lt $temp[$j]){
		$max=$temp[$j];}}
		if ($max lt 1.5){
			print "Error!!! Minimum Jdk1.5 is supported\n";
			print "Finding supported Jre\n";
			jreSet();
		}
          }
	}
	else{
		jreSet();
	}
  }
  else{ 
	jreSet();
  }
}
else{ 
print "No Java version is installed";
}
