package JIS4IRC;

# x201��JIS���Ѵ�����ݤΥ⡼�ɻ���
$x201_mode ="I7";
	# �ǽ��1ʸ����I�ޤ���J��ESC (J �ޤ��� ESC (I ���ڤ��ؤ���
	# 2ʸ���ܤ� 8��7��S �� 8��8bit�ǽ��Ϥ���7��&0x7f���롣 S��&0x7f��������������� \x0e,\x0f���ɲä��롣

# iso-2022-jp-3 �� 0208�Ȥθߴ����λ���
$iso2022jp3_mode =2;
	# 0=iso-2022-jp-3-compatible(����208)
	# 1=iso-2022-jp-3           (����213��1��)
	# 2=iso-2022-jp-3-auto      (x0208�ˤ���ʸ����x0208,¾��213��1��)

# ISO-2022-JP �Υ��������ץ�������
%escape2022 =(
	0   =>"\x1b\x28\x42",
	208 =>"\x1b\x24\x42",
	212 =>"\x1b\x24\x28\x44",
	2131=>"\x1b\x24\x28\x4f",
	2132=>"\x1b\x24\x28\x50",
);

# x0208 ��¸�ߤ���ʸ��
# ����94�Ĥ����ƻ��Ѥ���Ƥ����
$x208all = '!0123456789:;<=>?@ABCDEFGHIJKLMNPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrs';

# ���ΰ��������Ѥ���Ƥ����
%x208=(
	'"'=>'!"#$%&\'()*+,-.:;<=>?@AJKLMNOP\\]^_`abcdefghijrstuvwxy~',
	'#'=>'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz',
	'$'=>'!"#$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrs',
	'%'=>'!"#$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuv',
	'&'=>'!"#$%&\'()*+,-./012345678ABCDEFGHIJKLMNOPQRSTUVWX',
	'\''=>'!"#$%&\'()*+,-./0123456789:;<=>?@AQRSTUVWXYZ[\\]^_`abcdefghijklmnopq',
	'('=>'!"#$%&\'()*+,-./0123456789:;<=>?@',
	'O'=>'!"#$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRS',
	't'=>'!"#$%&',
);

sub _HexDump{
	my($s)=shift;
	$s =~s/([\x00-\x1f])/'%' . unpack('H2', $1)/eg;
	return $s;
}

sub _decodeX201{
	my($code,$mode,$shift)=@_;
	$code |= 0x80;
	return ($code >=0xa1 and $code <=0xdf)?("\x8e".chr($code)):("%".unpack('H2',$code));
}

sub toEUCJP{
	my $src = shift;
	defined $src or return undef;
	my $src_len = length $src;
	my @result;
	LOOP: for(my $i = 0;$i<$src_len;){
		# ESC ���о줹��ޤǤ���ʬ
		my $start = $i;
		$i = index $src,"\x1b",$i;
		$i == -1 and $i = $src_len;
		if($i>$start){
			my $part = substr($src,$start,$i-$start);
			$part =~ s/([\x80-\xff])/_decodeX201(ord($1),"b",0)/ge;
			push @result,$part;
		}
		my $maxescape = $src_len - 3;
		my $page = 0;
		for(;$i<$src_len;++$i){
			my $c = ord(substr($src,$i,1));
			# ����ʤ�ɬ��ASCII���᤹
			$c==0x20 and next LOOP;
			if($c==0x0E){ # shift out
				if($page==72010 ){ $page=72011; next; }
				if($page==82010 ){ $page=82011; next; }
				next LOOP;
			}
			if($c==0x0F){ # shift in
				if($page==72011){ $page=72010; next; }
				if($page==82011){ $page=82010; next; }
				next LOOP;
			}
			if($c==0x1B){
				my $elen = 1;
				if($i<=$maxescape){
					$elen = 3;
					my $c1 = substr($src,$i+1,1);
					my $c2 = substr($src,$i+2,1);
					if($c1 eq '('){
						if($c2 eq 'B'){$page=    0;$i+=2; next;}	# ASCII ESC (B ��������
						if($c2 eq 'I'){$page=72010;$i+=2; next;}	# JIS X 0201 �Ҳ�̾ 7�ӥå�Ⱦ�ѥ��ʤγ���
						if($c2 eq 'J'){$page=82010;$i+=2; next;}	# JIS X0201(LH) ESC (J Ⱦ�ѥ���

					}elsif($c1 eq '$'){
						if($c2 eq '@'){$page=2131; $i+=2; next;}	# ESC $@ JIS X 0213��1��(include JIS X0208('78)) 
						if($c2 eq 'B'){$page= 208; $i+=2; next;}	# JIS X0208('83) 
						if($c2 eq 'I'){$page= 201; $i+=2; next;}	# 8�ӥå�Ⱦ�ѥ��ʤγ���
						if($c2 eq '(' and $i<$maxescape){
							$elen = 4;
							my $c3 = substr($src,$i+3,1);
							if($c3 eq 'O'){$page=2131; $i+=3; next;}	# JIS X 0213��1��(include JIS X0212?)
							if($c3 eq 'P'){$page=2132; $i+=3; next;}	# JIS X 0213��2��
							if($c3 eq 'D'){$page=212;  $i+=3; next;}	# JIS X 0212 �������
						}
					}
				}
				warn "JIS4IRC: unsupported escape sequence "._HexDump(substr($src,$i,$elen)),"\n";
				push @result,substr($src,$i++,1);
				next LOOP;
			}
			@result>100 and @result= (join '',@result);
			if($page==0){ next LOOP;}
			elsif($page==208 or $page==2131 ){
				if($c<0x21 or $c>0x7E or $i==$src_len-1 ){ next LOOP;}
				my $c2 = ord(substr($src,$i+1,1));
				if($c2<0x21 or $c2>0x7E ){ next LOOP;}
				++$i;
				push @result,pack("CC",$c+0x80,$c2+0x80);
			}
			elsif($page == 201){push @result,_decodeX201($c,' ',0);}
			elsif($page==82010){push @result,_decodeX201($c,'J',0);}
			elsif($page==82011){push @result,_decodeX201($c,'J',1);}
			elsif($page==72010){push @result,_decodeX201($c,'I',0);}
			elsif($page==72011){push @result,_decodeX201($c,'I',1);}
			elsif($page==2132 or $page==212){
				if($c<0x21 or $c>0x7E or $i==$src_len-1 ){ next LOOP;}
				my $c2 = ord(substr($src,$i+1,1));
				if($c2<0x21 or $c2>0x7E ){ next LOOP;}
				++$i;
				push @result,"\x8f".pack("CC",$c+0x80,$c2+0x80);
			}
			else{ next LOOP; }
		}
	}
	return join '',@result;
}

sub fromEUCJP{
	my($src)=shift;
	defined $src or return undef;
	my $src_len = length $src;
	my $mode =-1;
	my $newmode;
	my $code;
	my $bytes;
	my @list;
	for(my $i=0;$i<$src_len;++$i){
		$bytes = substr($src,$i,1);
		$code = ord($bytes);
		if($code==0x8e and $src_len-$i >=2 ){
			$bytes = substr($src,++$i,1);
			$code = ord($bytes);
			if($code >=0xa1 and $code <=0xdf){
				$newmode = 201;
			}else{
				$newmode = 0;
			}
		}elsif($code==0x8f and $src_len-$i >=3 ){
			my $c1 = ord(substr($src,$i+1,1))-0xa0;
			$newmode = (( ($c1 >= 16 and $c1<=77) or grep{$c1 == $_} qw(2 6 7 9 10 11))?212:2132);
			$bytes = pack("CC"
				,ord(substr($src,$i+1,1))&0x7f
				,ord(substr($src,$i+2,1))&0x7f
			);
			$i+=2;
		}elsif($code>=0xa1 and $code<=0xFE and $src_len-$i >=2 ){
			$code &= 0x7f;
			my $c2 =ord(substr($src,++$i,1))&0x7f;
			$bytes = pack("CC",$code,$c2);

			# iso-2022-jp-3 ��ʸ����ϸߴ�������䤳����
			$newmode = $iso2022jp3_mode==0?208:2131;
			if($iso2022jp3_mode==2){
				my $ku = chr($code);
				if( -1!=index($x208all,$ku)
				or -1!=index(($x208{$ku} or ''),chr($c2))
				){ $newmode =208; }
			}
		}else{
			$newmode = 0;
		}
		$mode != $newmode and push @list,{ mode=>($mode = $newmode),bytes=>[]};
		my $ra = $list[$#list]{bytes};
		push @$ra,$bytes;
		@$ra >100 and @$ra = (join'',@$ra);
	}
	my @result;
	my $lastmode=0;
	for my $part (@list){
		my $bytes = join'',@{$part->{bytes}};
		if($part->{mode}==201){
			push @result,((-1!=index($x201_mode,"J"))?"\x1b(J":"\x1b(I");
			(-1!=index($x201_mode,"S")) and push @result,"\x0e";
			-1==index($x201_mode,"8") and $bytes =~ s/(.)/chr(0x7f&ord($1))/ge;
			push @result,$bytes;
			(-1!=index($x201_mode,"S")) and push @result,"\x0f";
		}else{
			$lastmode!=$part->{mode} and push @result,$escape2022{$part->{mode}};
			push @result,$bytes;
		}
		$lastmode = $part->{mode};
		@result>100 and @result= (join '',@result);
	}
	$lastmode !=0 and push @result,$escape2022{0};
	return join '',@result;
}

# references��
# http://www.asahi-net.or.jp/~wq6k-yn/code/enc-x0213.html
# http://www2d.biglobe.ne.jp/~msyk/charcode/jisx0201kana/
# http://www.m17n.org/m17n2000_all_but_registration/proceedings/kawabata/jisx0213.html

1;
