#!/usr/bin/perl

package Buffer ;
use strict;

sub new ## String /scalar
{
	my $ObjType=shift;
	my %Self = ( Buf	=> shift );
	return bless(\%Self,$ObjType);
}
sub Size
{
	my $Self=shift;
	return length($Self->{Buf});
}
sub ReadBytes  ### $Place, $Buffer , $Size
{
	my $Self=shift;
	my $Place=shift;
	my $Size=shift || 1;
	my $Result=0;
	while ( $Size ) 
	{
		my $Loaction= $Place+$Size  ;
        $Result = $Result * 0x100 + ord(substr($Self->{Buf},$Loaction-1,1));
	    $Size--;
	}
	return $Result;
}
sub String
{
	my $Self=shift;
	my $Place=shift;
	my $Size=shift;
	return $Size ? substr($Self->{Buf},$Place,$Size) : substr($Self->{Buf},$Place);
}

sub Buffer
{
	my $Self=shift;
	my $Place=shift;
	my $Size=shift;
	return Buffer->new($Self->String($Place,$Size));
}
sub Byte
{
	my $Self=shift;
	my $Place=shift;
	return $Self->ReadBytes($Place);
}
sub Word
{
	my $Self=shift;
	my $Place=shift;
	return $Self->ReadBytes($Place,2);
}
sub Long
{
	my $Self=shift;
	my $Place=shift;
	return $Self->ReadBytes($Place,4);
}

sub toString
{
	my $Self=shift;
	my @Result;
	my $LineSize=16;
	my $LineStr;
	for (my $i=0 ; $i < $Self->Size() ; $i++) 
	{
		$i % $LineSize and $LineStr .= sprintf("%02X ",$Self->Byte($i)) , next;
		if ( $LineStr ) 
		{
			$LineStr .= "    " . $Self->String($i - $LineSize ,$LineSize);
			$LineStr =~ s/[^\w\:\{\[\}\]\ \<\>]/\./g ;
			push(@Result,$LineStr);
		}
		$LineStr=sprintf("%04X: %02X ",$i,$Self->Byte($i));
	}
	my $More=$Self->Size % $LineSize ;
	if ( $More ) 
	{
		$LineStr .= ' ' x (($LineSize - $More)*3 + 5) . $Self->String(-$More);
		$LineStr =~ s/[^\w\s\:]/\./g ;
		push(@Result,$LineStr);
	}
	return wantarray ? @Result : join('\n',@Result); 
}

package BaseObj ;
use strict ;

sub new
{
	my $OBJType=shift;
	my %Self = ( @_ );
	my $DebugModule="Debug";
	$OBJType =~ /\:([^\:]+?)$/ and $DebugModule .= $1;
	exists $Self{$DebugModule} and $Self{Debug}=1;
	return bless(\%Self,$OBJType);
}
sub Logger
{
	my $Self=shift;
	if ( exists $Self->{Loger} and ( ref($Self->{Loger}) =~ /CODE/)  )
	{
		$Self->{Loger}->(@_);
		return ;
	}
	### print '=' x 60 ,ref($Self->{Loger} ), __PACKAGE__ ,"\n";
	foreach my $Line ( @_ ) 
	{
		print "$Line\n";
	}
}

sub getLogOptions
{
	my $Self=shift;
	my %Result ;
	my @OpKeys=grep(/Debug/,keys(%$Self));
	push(@OpKeys,"Loger","FileName");
	## exists $Self->{Loger} and $Result{Loger}=$Self->{Loger};
	foreach my $KeyIter (@OpKeys) 
	{
		exists $Self->{$KeyIter} or next ;
		$Result{$KeyIter}=$Self->{$KeyIter};
	}
	return %Result;
}

package mdbReader ;

use strict;
use Fcntl;
our @ISA=("BaseObj");

sub new
{
	my $ObjType=shift;
	my $Self=$ObjType->SUPER::new( ( UsageOffset => 0 ,
									 PgSize	=>	4096 ,
									 @_) );
	return bless($Self,$ObjType);
}

sub Test
{
	my $Self=shift;
	my $Start=shift;
	my $Range=shift;
	$Range += $Start;
	$Self->{Debug}=1;
	return $Self->getPages(($Start..$Range));
}

sub getPages
{
   my $Self=shift;
   my @PgList=@_;
   my @Result;
   my $LastPos=-1;
   my $pgNum=0;
   my $Err;
   my @Result;
   my $Offset= $Self->{UsageOffset};
   $Err = (open MDBFILE ,"<$Self->{FileName}") ? 0 : 1;
   if ( $Err ) 
   {
		$Self->Logger("Error - Fail to open File $Self->{FileName}");
		return ();
   }
   binmode(MDBFILE); 
				####  Fcntl::SEEK_SET = 0
   $Err += (seek(MDBFILE,$Offset,0)) ? 0 : 1 ;
   exists $Self->{Debug} and $Self->Logger(sprintf("Debug - %s - getPages: Seek to offset $Offset Result $Err",__PACKAGE__));
   while ( @PgList ) 
   {
	    my $Buffer="";
		$pgNum=shift(@PgList);					######### Fcntl::SEEK_CUR = 1
		$Err += (seek(MDBFILE,$Self->{PgSize} * ($pgNum - $LastPos -1) ,1)) ? 0 : 1;
		exists $Self->{Debug} and $Self->Logger("Debug - after Seek from page $LastPos to Page $pgNum $Err <$?> ");
		$Err or my $TmpErr += read(MDBFILE,$Buffer,$Self->{PgSize} ) ;
		if ( defined $TmpErr ) 
		{
			exists $Self->{Debug} and $Self->Logger($TmpErr ? "Debug - getPages: Read Succesfully $TmpErr Bytes" : 
				"Debug - getPages: Read till End of File ...");
		} else { $Err++ }
			## exists $Self->{Debug} and $Self->Logger("Debug - Error counter after reading Page $pgNum $Err");
		if ( $Err ) 
		{
			$Self->Logger("Error - Fail to read Page $pgNum from $Self->{FileName}");
			close MDBFILE ;
			return ();
		}
		my $TmpBuf=Buffer->new($Buffer);
		my $TmpPage=mdbReader::Page->new($TmpBuf,$pgNum,$Self->getLogOptions());
		$LastPos=$pgNum;
		$TmpPage or next;
		push(@Result,$TmpPage);
		
   }
   close MDBFILE ;
   return @Result;
}

package mdbReader::Parser ;
our @ISA=("mdbReader");

sub parse_file
{
	my $ObjType=shift;
	my $FileName=shift;
	my $Self=$ObjType->SUPER::new( ( ## $FileName ,
									 FileName	=>	$FileName ,
									 @_) );
	my %CatalogList;
	exists $Self->{Debug} and $Self->Logger(sprintf("Debug - %s parse_file: about to read Page 2 from $Self->{FileName}",__PACKAGE__));
	my @DefPg=$Self->getPages(2);
	## my $DefPg=mdbReader::TDefPg->new($Self,2,$Self->getLogOptions());
	@DefPg or return undef;
	my $TmpTable=mdbReader::Table->new($DefPg[0],$Self->getLogOptions());
	exists $Self->{Debug} and $Self->Logger("Debug - Build Catalog for $Self->{FileName}");
	my @CatRows=$TmpTable->getRows("Name","Type","Id","ParentId","Flags");
    exists $Self->{Debug} and $Self->Logger(sprintf("Debug - parse_file: Catalog Table Contain %d Rows",$#CatRows+1));
	foreach my $RowVal (@CatRows ) 
	{
		my $TableName=shift(@$RowVal);
		$CatalogList{$TableName}=$RowVal;
		exists $Self->{Debug} and $Self->Logger(sprintf("Debug - %s parse_file: Insert to Catalog $TableName",__PACKAGE__));
	}
	$Self->{Catalog}=\%CatalogList;
	return bless($Self,$ObjType);
}

sub getTableByName
{
	my $Self=shift;
	my $Name=shift;
	unless ( exists $Self->{Catalog}->{$Name} and $Self->{Catalog}->{$Name}->[0] == 1 ) 
	{
		$Self->Logger("Error - Table $Name not exist / found at $Self->{FileName}");
		exists $Self->{Catalog}->{$Name} and $Self->Logger("Debug $Self->{Catalog}->{$Name} is of type $Self->{Catalog}->{$Name}->[0]");
		return undef;
	}
	my @DefPg=$Self->getPages($Self->{Catalog}->{$Name}->[1]);
	my $Table=mdbReader::Table->new($DefPg[0],$Self->getLogOptions());
	return $Table;
}

sub getTableList
{
	my $Self=shift;
	my @Result;
	my @DebugStr=("%-40s %-6s %-10s %-10s %-5s" ,
				  "%-40s %-6d %-10d %-10d %-5d");
	exists $Self->{Debug} and $Self->Logger(sprintf($DebugStr[0],"Name","Type","Id","ParentId","Flags"),'-' x 100);
	while ( my ($TblName,$TablVal) = each(%{$Self->{Catalog}}) ) 
	{
		exists $Self->{Debug} and $Self->Logger(sprintf($DebugStr[1],$TblName,@$TablVal));
		### Return just Tables Type ...
		$$TablVal[0] == 1 and  push(@Result,$TblName);
	}
	return @Result;
}

package mdbReader::Table ;
our @ISA=("mdbReader");

use constant {
	OffsetMask	=>	0x2000 ,
	SkipRowFlag	=>  0x4000 ,
	Byte		=>  1,
	Word		=>  2,
	Long		=>  4  } ;

sub new 
###############################################################################
#
# Input:	$MdbObj , $PageStart  - the First page of the table. [%options]
#
# Return:
#
# Description:  Reads Table from Mdb that start at page $PageStart
#
###############################################################################
{
   my $ObjType=shift;
   my $DefPage=shift;
   my $Self=$ObjType->SUPER::new( ## $DefPage->{FileName},
									( ## Mdb	=> $DefPage , 
									FirstPg  => $DefPage->{PgNum} ) ,
								   @_ );

   $Self->{RowNums}=$DefPage->{Buf}->Long(16);
   $Self->{ColumnsNum}=$DefPage->MaxRows();
   $Self->{NumOfIndx}=$DefPage->{Buf}->Long(47);        #        mdbReader::ReadBytes(47,$Self{Mdb}->{Buffer},4);
   $Self->{NumOfRIdx}=$DefPage->{Buf}->Long(51);        #      mdbReader::ReadBytes(51,$Self{Mdb}->{Buffer},4);
   $Self->{FirstDataPg}=$DefPage->{Buf}->Word(56);
   my %CollumnList;
   my $NextCollNamePos=$Self->{ColumnsNum}*25+$DefPage->RowIndex();
   for (my $CoIndx=0 ; $CoIndx < $Self->{ColumnsNum} ; $CoIndx++ ) 
   {
	   #$Self->Logger("Debug - read Collumnn by getRow ($DefPage)....");
	   my $TmpCollBuf=$DefPage->getRow($CoIndx);
	   #$Self->Logger("Debug - after Collumnn by getRow ....");
	   unless ( defined $TmpCollBuf ) 
	   {
		   $Self->Logger("Error - Collumn $CoIndx not exist at Table");
		   return undef;
	   }
	   exists $Self->{Debug} and $Self->Logger("Debug Column $CoIndx Content:",$TmpCollBuf->toString());
	   my $CollNameSize=$DefPage->{Buf}->Word($NextCollNamePos);
	   my $CollName=$DefPage->{Buf}->String($NextCollNamePos+2,$CollNameSize);
	   exists $Self->{Debug} and $Self->Logger("Debug Collumn Name:$CollName");
	   ### $CollName =~ s/\0//g;
	   my $TmpColumnRec=mdbReader::Collumn->new($CollName,$TmpCollBuf,@_);
	   $CollumnList{$TmpColumnRec->{Name}}=$TmpColumnRec;
	   $NextCollNamePos += $CollNameSize + 2;
   }
   $Self->{ColList}=\%CollumnList;
   exists $Self->{Debug} and $Self->Logger("Debug - mdbReader::Table: Read First DataPage $Self->{FirstDataPg}");
   my @TablePages=$Self->getPages($Self->{FirstDataPg});
   @TablePages or $Self->Logger("Error - Fail to read Data pages. Skip Table Reading."),return;
   exists $Self->{Debug} and $Self->Logger(sprintf("Debug - mdbReader::Table: Usage Map Row Index is: %d",$DefPage->{Buf}->Byte(55)));
   my $UsageMapRow = $TablePages[0]->getRow($DefPage->{Buf}->Byte(55));
   exists $Self->{Debug} and $Self->Logger("Debug - mdbReader::Table: Content of UsageMap:",$UsageMapRow->toString);
   my @MaskBit=( 0x01,0x02,0x04,0x08,0x10,0x20,0x40,0x80);
   @TablePages=();
   if ( $UsageMapRow->Byte(0) ) 
   {
		$Self->Logger(sprintf("Error - Usage map %d Not supported yet.",$UsageMapRow->Byte(0)));
		return undef;
   }
   $Self->{UsageOffset}=$UsageMapRow->Long(1);
   $Self->{UsageMap}=$UsageMapRow->Buffer(5);
   return bless($Self,$ObjType) ;
}

sub getRows  ### @NameList of Columns
{
	my $Self=shift;
	my @NameList= @_  ? @_ : $Self->collumnsNameList();
	my @MaskBit=( 0x01,0x02,0x04,0x08,0x10,0x20,0x40,0x80);
    my @TablePages=();
	my @Result;
	## ColList
	### Read all Pages  ###
	exists $Self->{Debug} and $Self->Logger("Debug - Calculate The Pages of this Table:",$Self->{UsageMap}->toString);
	for ( my $ByteCount=0; $ByteCount < $Self->{UsageMap}->Size ; $ByteCount++ ) 
    {
	   my $BitMask=$Self->{UsageMap}->Byte($ByteCount);
	   $BitMask or next;
	   exists $Self->{Debug} and $Self->Logger(sprintf("Debug - Found out Relevant Page at range: %d - %d ($ByteCount)",$ByteCount * 8,($ByteCount + 1) * 8 -1));
	   for ( my $i=0 ; $i < @MaskBit ; $i++)
	   {
			int( $BitMask / $MaskBit[$i] ) % 2 or next ;
			push(@TablePages,$ByteCount * 8 + $i);
	   }
   }
   exists $Self->{Debug} and $Self->Logger("Debug - Start to Read Table Rows data ....");
   @TablePages= $Self->getPages(@TablePages);
   @TablePages or $Self->Logger("Warnning - no Pages found for this table"),return @Result;
   my $RowCounter=$Self->{RowNums};
   
   foreach my $PgObj ( @TablePages ) 
   {
		for ( my $RowNum=0 ; $RowNum <  $PgObj->MaxRows() ; $RowNum++ ) 
		{
			$PgObj->RowDelFlag($RowNum) and next;
			exists $Self->{Debug} and $Self->Logger("Debug - mdbReader::Table::getRows: Creating Row number $RowNum");
			my $TmpRow=$PgObj->getRow($RowNum);
			exists $Self->{Debug} and $Self->Logger(sprintf("Debug - mdbReader::Table::getRows: Row $RowNum have overflow flag: %d",$PgObj->LookUpFlag($RowNum)));
			$TmpRow=$PgObj->LookUpFlag($RowNum) ? mdbReader::OverFlowRow->new($TmpRow,$Self,$Self->getLogOptions()) :
							mdbReader::Row->new($TmpRow,$Self,$Self->getLogOptions());	
			## my $TmpRow=
			$TmpRow->{SkipFlag} and next;
			$RowCounter--;
			my @Answer=$TmpRow->getValues(@NameList);
			exists $Self->{Debug} and $Self->Logger("Debug - mdbReader::Table::getRows :::: RowVals: @Answer");
			push(@Result,[@Answer]);
				##undef @Answer;
			$RowCounter or last;
			exists $Self->{Debug} and $Self->Logger("Debug - >>>>>>>>>>>>>>>>>>>>>>   New Row Reading       <<<<<<<<<<<<<<<<<<<<<<<<");
		}
		$RowCounter or last;
		exists $Self->{Debug} and $Self->Logger("Debug - mdbReader::Table::getRows Finish to parse Page $PgObj->{PgNum} moving to next page (Last Page):",$PgObj->{Buf}->toString());
	}
	exists $Self->{Debug} and $Self->Logger(sprintf("Debug - mdbReader::Table::getRows: Number of Rows return : %d",$#Result+1));
   $RowCounter and $Self->Logger("Error - Finish to read all Pages but still tere are more $RowCounter missing Rows"),return;
   return @Result;
}

sub collumnsNameList
{
	my $Self=shift;
	return keys(%{$Self->{ColList}});
}

package mdbReader::Collumn ;
our @ISA=("mdbReader");
sub new 
{
	my $ObjType=shift;
	my $Name=shift;
	my $Content=shift;
	$Name =~ s/\0//g;

	my $Self = $ObjType->SUPER::new( 
			(	 Type	=> $Content->Byte(0) ,
			     ColNum	=> $Content->Byte(5) ,
		         Var_ColNum => $Content->Word(7) ,
				 NumofRows	=> $Content->Word(9) ,
				 IsFixed	=> $Content->Word(15) % 2 ,
				 FixedOffset => $Content->Word(21) ,
				 ColSize	=>  $Content->Word(23) ,
				 Name		=>  $Name ,
				 @_ ) );
	my $Obj=getType($Self->{Type});
	$Obj =~ /([^\:]+?)$/ and exists $Self->{"Debug$1"} and $Self->{Debug}=1;
	return $Obj->new(%$Self);
}

sub getType
{
	my $Self = shift;
	my $Indx=1;
	my $Type;
	my @ColumnType=( ["BOOL","mdbReader::Collumn::Number"] ,   
					 ["BYTE","mdbReader::Collumn::Number"] ,
					 ["INT","mdbReader::Collumn::Number"],
					 ["LONGINT","mdbReader::Collumn::Number"],
					 ["MONEY","mdbReader::Collumn::Number"],
					 ["FLOAT","mdbReader::Collumn::Number"],
   					 ["DOUBLE","mdbReader::Collumn::Number"],
					 ["SDATETIME","mdbReader::Collumn::Text"],
					 ["ERROR","mdbReader::Collumn::Number"],
					 ["TEXT","mdbReader::Collumn::Text"],
					 ["OLE","mdbReader::Collumn::Text"],
   					 ["MEMO","mdbReader::Collumn::Memo"],
					 ["D_Unknowen","mdbReader::Collumn::Text"],
					 ["E_Unknown","mdbReader::Collumn::Text"],
					 ["REPID","mdbReader::Collumn::Text"],
					 ["NUMERIC","mdbReader::Collumn::Number"]);
	if  ( ref($Self) )
	{
		$Type =  $Self->{Type};
		$Indx=0;
	} else { $Type = $Self; }
	return  $Type > @ColumnType ? "Error Type ($Type) Out of Range" : $ColumnType[$Type-1]->[$Indx];
}

package mdbReader::Collumn::Text ;
our @ISA=("mdbReader::Collumn");
sub new 
{
	my $ObjType=shift;
	my %Self=@_;
	return bless(\%Self,$ObjType);
}

sub getVal
{
	my $Self=shift;
	my $Buf=shift;
	$Buf->Word(0) == 0x2E and return "";  ## Null Value
	my $Result=$Buf->Word(0) > 0xF0F0 ? $Buf->String(2) : $Buf->String(0);
	$Result =~ s/\0//g;
	return $Result;
}

package mdbReader::Collumn::Number ;
our @ISA=("mdbReader::Collumn");
sub new 
{
	my $ObjType=shift;
	my %Self=@_;
	return bless(\%Self,$ObjType);
}

sub getVal
{
	my $Self=shift;
	my $Buf=shift;
	my $TmpVal=$Buf->ReadBytes(0,$Buf->Size);
	$Self->getType() eq "LONGINT" and $TmpVal= $TmpVal > 0x80000000 ? $TmpVal - 0xFFFFFFFF : $TmpVal;
	return $TmpVal;
}

package mdbReader::Collumn::Memo ;
our @ISA=("mdbReader::Collumn");
sub new 
{
	my $ObjType=shift;
	my %Self=@_;
	return bless(\%Self,$ObjType);
}

sub getVal
{
	my $Self=shift;
	my $Buf=shift;
	my $MemoSize=$Buf->Word(0);
	my $MemoType=$Buf->Word(2);
	exists $Self->{Debug} and $Self->Logger(sprintf("Debug - Memo record (%04X) :",$MemoType),$Buf->toString());
	if ( $MemoType >= 0x8000 ) 
	{
		exists $Self->{Debug} and $Self->Logger("Debug - Memo record is local");
		return $Buf->String($Buf->Word(12) > 0xF0F0 ? 14 : 12 ,$MemoSize);
	} elsif ( $MemoType >= 0x4000 ) 
	{
		my $LvlPg=$Buf->Byte(5);
		my $LvlRow=$Buf->Byte(4);
		exists $Self->{Debug} and $Self->Logger("Debug - read Memo record from Page $LvlPg");
		my @LValPage=$Self->getPages($LvlPg);
		@LValPage or $Self->Logger("Error - Fail to read Lval Page return Null Value"),return ;
		$Buf=$LValPage[0]->getRow($LvlRow);
		exists $Self->{Debug} and $Self->Logger("Debug - Memo record Page $LvlPg return value:",$Buf->toString());
		return $Buf ? $Buf->String($Buf->Word(0) > 0xF0F0 ? 2 : 0 ) : undef;
	} else
	{
		$Self->Logger("Error - Unsuported Memo Record type(2): Record $MemoType","\t - Record Content:",$Buf->toString());
		return ;
	}
}

package mdbReader::Row ;
## our @ISA=("mdbReader::Table");
our @ISA=("mdbReader");
sub new  ### $RowNumber
# RowRec   1. Order ?  , 2. Null/Exist , 3. Fixed/Var , 4. offset , 5. size , 6. Type
{
	my $ObjType=shift;
	my $Buff=shift;
	my $Table=shift;
	my $Self = $ObjType->SUPER::new(## $Table->{FileName} ,
									( Content => $Buff , 
									  SkipFlag	=> 0 ,     ### $Buff->Word(0) > 0x4000 ,
									  NumOfFields => $Buff->Word(0) % 0x4000 ) ,
									##   FileName => $Table->{Mdb}->{FileName} ,
									  Fields => $Table->{ColList} ,
									  @_);
	$Table->{ColumnsNum} != $Self->{NumOfFields} and $Self->Logger("Warning - Number of Table fields $Table->{ColumnsNum} don't match number of Row Fields $Self->{NumOfFields}");
    $Self->{NumOfFields}=$Table->{ColumnsNum};
	my %CollPointer;
	exists $Self->{Debug} and $Self->Logger(sprintf("Debug - mdbReader::Row::new Number of collumns $Self->{NumOfFields} [ $Self->{Table}->{ColList} ] (%d)",0));
	exists $Self->{Debug} and $Self->Logger("Debug - Row Content :",$Self->{Content}->toString);
	return bless($Self,$ObjType);
}

sub getFieldMask
{
	my $Self=shift;
	my @MaskBit=( 0x01,0x02,0x04,0x08,0x10,0x20,0x40,0x80);
	my $MaskFiledSize=( ( $Self->{NumOfFields} -1 ) / 8 ) +1 ;
	my $MaskBitMap=$Self->{Content}->Buffer(-$MaskFiledSize);
	my $ByteMask;
	my @Result;
	for (my $i=0 ; $i < $Self->{NumOfFields} ; $i++ ) 
	{
		$i % 8 or $ByteMask=$MaskBitMap->Byte(int($i/8));
		push(@Result, ($ByteMask / $MaskBit[$i % 8]) % 2);
		exists $Self->{Debug} and $Self->Logger(sprintf "Debug - Field $i -> %s ($ByteMask)/ %d \n",(($ByteMask / $MaskBit[$i % 8]) % 2) ? "Exists" : "Null" , $MaskBit[$i % 8]); 
 	}
	return @Result;
}

sub getValues
{
	my $Self=shift;
	my @Names=@_;
    exists $Self->{Debug} and $Self->Logger("Debug - mdbReader::Row::getValues Input: @Names" ,
							sprintf("Debug - Row Content (%d):",$Self->{Content}->Size),
							$Self->{Content}->toString);
	my @NullFields=$Self->getFieldMask();
	my @Result;
	my %FIndex=%{$Self->{Fields}};
	my ($Location,$Size);
	my $MaskFiledSize=int( ( $Self->{NumOfFields} -1 ) / 8 ) +1 ;
	my $VarayColumns=$Self->{Content}->Word(-1 * ($MaskFiledSize + 2));
	my $IndexPointer=$MaskFiledSize + 4 ;
	## my $VarayColumnCounter=0;
	exists $Self->{Debug} and $Self->Logger("Debug - mdbReader::Row::getValues MaskBitMap Size (in Bytes $MaskFiledSize ), Start Index positon $IndexPointer");
	foreach my $Name ( @Names ) 
	{
		unless ( exists $FIndex{$Name} ) 
		{
			$Self->Logger("Warning - The Field $Name do not exists at Row Table ! $Self->{Fields}",join(" , ",keys(%FIndex)));
			push(@Result,"");
			next ;
			## return undef;
		}
		exists $Self->{Debug} and $Self->Logger("Debug - mdbReader::Row::getValues $Name position ($FIndex{$Name}->{ColNum})");
		unless ( $NullFields[$FIndex{$Name}->{ColNum}]  ) 
		{  ###  Null Field !   #
			exists $Self->{Debug} and $Self->Logger("Debug - mdbReader::Row::getValues $Name is null ($FIndex{$Name}->{ColNum})");
			push(@Result,"");
			next ;
		}

		if ( $FIndex{$Name}->{IsFixed} ) 
		{
			$Location=$FIndex{$Name}->{FixedOffset}+2;
   			$Size=$FIndex{$Name}->{ColSize};
			 exists $Self->{Debug} and $Self->Logger("Debug - mdbReader::Row::getValues $Name is Fixed Column");
		} else
		{  #### Varay Field
			$Location=$Self->{Content}->Word(-1*($IndexPointer+$FIndex{$Name}->{Var_ColNum}*2));
			exists $Self->{Debug} and $Self->Logger(sprintf("Debug - mdbReader::Row::getValues $Name Index of next location -(%d) , Start Location %d",
									$IndexPointer+$FIndex{$Name}->{Var_ColNum}*2+2,$Location),
									"Debug - mdbReader::Row::getValues $Name is column $FIndex{$Name}->{Var_ColNum} out of $VarayColumns");
			## $VarayColumnCounter++;
			#for ( my $Step=2 , $Size=0 ; $Size==0 ; $Step += 2) 
			##{
			###	exists $Self->{Debug} and $Self->Logger("Debug - mdbReader::Row::getValues Step $Step , Size $Size");
				$Size = $FIndex{$Name}->{Var_ColNum}   <= $VarayColumns ? 
						$Self->{Content}->Word(-1*($IndexPointer+$FIndex{$Name}->{Var_ColNum}*2 + 2 ) ) - $Location : 
							 $Self->{Content}->Size - $VarayColumns * 2 - $MaskFiledSize - $Location ;
							 ## $Self->{Content}->Size - $Location - $MaskFiledSize - 2;
				exists $Self->{Debug} and $Self->Logger(sprintf("Debug - Index Calculation of next Collumn %d (MaxVaray:%d)", $FIndex{$Name}->{Var_ColNum} ,$VarayColumns));
				##exists $Self->{Debug} and $Self->Logger(sprintf("Debug - mdbReader::Row::getValues After calaculation Size $Size ( next Index location -(%d) or MaxPosition calculated:  %d",
				##									$IndexPointer+$VarayColumnCounter*2 + $Step , $Self->{Content}->Size - $Location - $MaskFiledSize - 2));
			##}
			
			exists $Self->{Debug} and $Self->Logger("Debug - mdbReader::Row::getValues $Name is Varay Column Coll Num $FIndex{$Name}->{Var_ColNum}");
		}
		push(@Result,$Size ? $FIndex{$Name}->getVal($Self->{Content}->Buffer($Location,$Size)) : "" );
		exists $Self->{Debug} and $Self->Logger(sprintf("Debug - %s getValues Column $Name (%s) Value: %s",
						ref($Self),$FIndex{$Name}->getType(),$Result[-1] or "Null Value"));
	}
	
	return  @Result;
}

package mdbReader::OverFlowRow ;
## our @ISA=("mdbReader::Row");
sub new
{
	my $ObjType=shift;
	my $Buff=shift;
	my $Table=shift;
	## my $Self=$ObjType->SUPER::new($Buff,$Table);

	my $RowPg=$Buff->Byte(1);
	my $RowNum=$Buff->Byte(0);
	my @TmpPg=$Table->getPages($RowPg);
	@TmpPg or $Table->Loger("Error - Fail to Find overflow Row at Page $RowPg Row $RowNum. Orig row Content:",$Buff->toString()),return ;
	my $NewRow=$TmpPg[0]->getRow($RowNum);
	return mdbReader::Row->new($NewRow,$Table);
}

package mdbReader::Page ;
## use mdbReader;
our @ISA=("mdbReader");

sub new
{
	my $ObjType=shift;
	my $PgBuffer=shift ;
	## my $MdbObj=shift;
    my $PageNumber=shift;
	my %PageType= (  TableDef	=> "mdbReader::Page::TDefPage" ,
					 DataPage   => "mdbReader::Page::DataPage" ,
					 LvalPage	=> "mdbReader::Page::LvalPage" );

	my $PageDef="Unknown";

	if ( $PgBuffer->Byte(0) == 1 ) 
	{
		$PageDef=$PgBuffer->String(4,4) eq "LVAL" ? "LvalPage" : "DataPage" ;
	} elsif ( $PgBuffer->Byte(0) == 2 ) 
	{
		$PageDef="TableDef";
	}
	unless ( exists $PageType{$PageDef} ) 
	{
		my $Self=BaseObj->new(@_);
		$Self->Logger("Error - Page number $PageNumber - is unsupported",$PgBuffer->Buffer(0,15)->toString());
		return undef;
	}

	my $Self=mdbReader->new(( Buf	=>  $PgBuffer ,
							 PgNum	 => $PageNumber ,
							 @_ ) );
	
	exists $Self->{Debug} and $Self->Logger("Debug Page $PageNumber :",$PgBuffer->toString());
	return $PageType{$PageDef}->new($Self);
}

sub FindRow
{
	my $Self=shift;
	my $RowNum=shift;
	$RowNum > $Self->MaxRows() and return undef ;
	my $Result = $RowNum < 0 ? $Self->{Buf}->Size + 1 : $Self->{Buf}->Word($Self->RowIndex + $RowNum * 2 ) ;
	exists $Self->{Debug} and $Self->Logger(sprintf("Debug - %s FindRow: Rows in this Page (%d): %d , Offset of Row $RowNum: %X",
					ref($Self),$Self->{PgNum},$Self->MaxRows(),$Result));
	return $Result % 0x2000;
}

sub RowDelFlag
{
	my $Self=shift;
	my $RowNum=shift;
	exists $Self->{Debug} and $Self->Logger("Debug - RowDelFlag Obj $Self , Max rows on this page :",$Self->MaxRows());
	$RowNum > $Self->MaxRows() and return undef ;
	my $RowIndx=$Self->{Buf}->Word($Self->RowIndex+$RowNum * 2);
	exists $Self->{Debug} and $Self->Logger("Debug - RowDelFlag Obj $Self , RowIndex:$RowIndx");
	return int( $RowIndx / $Self->{DelFlag} ) % 2 ;
}

sub LookUpFlag
{
	my $Self=shift;
	my $RowNum=shift;
	exists $Self->{Debug} and $Self->Logger(sprintf("Debug - %s LookUpFlag: (Page %d) Input: $RowNum MaxRows %d",ref($Self),$Self->{PgNum},$Self->MaxRows()));
	$RowNum > $Self->MaxRows() and return undef ;
	my $RowIndx=$Self->{Buf}->Word($Self->RowIndex+$RowNum * 2 );
	exists $Self->{Debug} and $Self->Logger(sprintf("Debug - %s LookUpFlag: Row offset value:  $RowIndx",ref($Self),$RowIndx));
	return int( $RowIndx / $Self->{LookUpFlag} ) % 2 ;
}

sub getRow
{
	my $Self=shift;
	my $RowNum=shift;
	exists $Self->{Debug} and $Self->Logger("Debug - Page get row $RowNum",$Self->MaxRows() );
	$RowNum > $Self->MaxRows() and return undef ;
	my $RowLocation=$Self->FindRow($RowNum);
	my $RowSize = $Self->FindRow($RowNum-1) - $RowLocation ;
	exists $Self->{Debug} and $Self->Logger("Debug - Page get row $RowNum location $RowLocation , $RowSize :");
	return $Self->{Buf}->Buffer($RowLocation,$RowSize);
}

package mdbReader::Page::TDefPage;
our @ISA=("mdbReader::Page");
sub new
{
	my $ObjType=shift;
	my $Self=shift;
	$Self->{TableSize}=$Self->{Buf}->Long(8);
	return bless($Self,$ObjType);
}

sub MaxRows
{
	my $Self=shift;
	### Number of Collumns ####
	return $Self->{Buf}->Word(45);
}

sub RowIndex
{
	my $Self=shift;
	return $Self->{Buf}->Long(51)*12 + 63 ;
}

sub FindRow
{
	my $Self=shift;
	my $RowNum=shift;
	$RowNum > $Self->MaxRows() and return undef ;
	exists $Self->{Debug} and $Self->Logger("Debug - FindRow Obj $Self , RowIndex:",$Self->RowIndex());
	return $Self->RowIndex + $RowNum * 25 ;
}
	## return $Result ;
sub getRow
{
	my $Self=shift;
	my $RowNum=shift;
	exists $Self->{Debug} and $Self->Logger("Debug - Page get row $RowNum",$Self->MaxRows() );
	$RowNum > $Self->MaxRows() and return undef ;
	my $RowLocation=$Self->FindRow($RowNum);
	return $Self->{Buf}->Buffer($RowLocation,25);
}

package mdbReader::Page::DataPage; 
our @ISA=("mdbReader::Page");
sub new
{
	my $ObjType=shift;
	my $Self=shift;
	$Self->{DelFlag}=0x8000;
	$Self->{LookUpFlag}=0x4000;
	return bless($Self,$ObjType);
}

sub MaxRows
{
	my $Self=shift;
	return $Self->{Buf}->Word(12);
}

sub RowIndex
{
	my $Self=shift;
	return 14 ;
}

sub FindRow
{
	my $Self=shift;
	my $RowNum=shift;
	my $Result=$Self->SUPER::FindRow($RowNum);

	#$RowNum > $Self->MaxRows() and return undef ;
	#my $Result = $RowNum < 0 ? $Self->{Buf}->Size + 1 : $Self->{Buf}->Word($Self->{RowIndex} + $RowNum * 2 ) ;
	return $Result ? $Result % 0x2000 : undef ;
}


package mdbReader::Page::LvalPage;
our @ISA=("mdbReader::Page");
sub new
{
	my $ObjType=shift;
	my $Self=shift;
	## my %Self=( @_ );
	return bless($Self,$ObjType);
}

sub MaxRows
{
	my $Self=shift;
	return $Self->{Buf}->Word(12);
}
sub RowIndex
{
	my $Self=shift;
	return 14 ;
}

1;