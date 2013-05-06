#!/usr/bin/perl
#
# Creates a unigram, bigram and trigram models using add-1 smoothing
# Contains functions for generating random sentences from
# the models.
#
# Run:
#  generate.pl ngrammodel number_of_sentences train.txt 
# e.g, generate pl n2 10 train.text
#
# by Maria Holmqvist 2008


## Variable declarations 
my $n = $ARGV[0];       	   # n1 unigram model, n2 bigram model, n3 trigrammodel
my $number = $ARGV[1];         # number of sentences to generate
my $trainfile = $ARGV[2];      # Build language model from this text

my %wordhash = ();      # Hash mapping word -> integer
my %wordhashrev = ();      # Hash mapping integer -> word

my %unigramcount = ();  # Hash containing unigram counts , w1 -> n(w1)

my %bigramcount = ();   # Hash containing hashes of bigram counts
                        #   w1  -> { w2 -> n(w1 w2)
                        #            w3 -> n(w1 w3)
                        #            w5 -> n(w1 w5) }                       
                        #
                        #   w2  -> { w1 -> n(w2 w1)
                        #            w3 -> n(w2 w3)
                        #            w6 -> n(w2 w6) }
                        #   ...
                        #
                        #   w(n) -> ...

 my %trigramcount = ();  # Hash containing hashes of trigram counts

## "Main" part of program

my @words = &readfile($trainfile);    # Get a list of words in training text

# Build model
&getcounts;                       # Count bigrams and unigrams
&add_x(1);                        # Calculate probabilities and smoothing values  (add 1)
&generate_text($number, $n);

#################
#               
#  Subroutines:  
#               
#################

### Calculate ADD-ONE smoothed bigrammodel ###

sub add_x {
  my ($constant) = @_;
  my @wordtypes = keys(%unigramcount);         # Get a list of wordtypes from the keys of the unigramcount-hash
  my $types = @wordtypes;                      # Get the number of types by assigning the list to a scalar variable
  my $add = $constant;                         # Count to add to all bigrams
  
  @newlist = grep($_ eq "",@wordtypes);
  
  if (@newlist) {
	print "Empty word: @newlist\n";
  }

  #print "Creating bigrammodel using add_x, x = $add\n"; 

  %bigrammodel = ();

  foreach $word1 (@wordtypes) {
    my %secondhash = %{ $bigramcount{$word1} };   # $bigramcount{$word1} contains a reference to a hash
                                                  # The hash is de-referenced using: %{ <reference> }
    my %hash;                                     # Create hash for probabilities
    
    foreach $word2 (keys(%secondhash)) {   
      # Calculating probability for bigram "$word1 $word2"
      $hash{$word2} = log2 (($secondhash{$word2} + $add)/($unigramcount{$word1} + $add * $types));
    }

    $hash{"smooth"} = log2 ($add / ($unigramcount{$word1} + $add * $types));   # Add smoothing value for unseen bigrams "word1 X"
    $bigrammodel{$word1} = \%hash;                                             # Add a reference to %hash
  } 
 
  my %hash;
  $hash{"smooth"} = log2 ( $add/($add + $types * $add) );          ## Smoothing value for bigrams starting with unknown word
  $bigrammodel{0} = \%hash; 
}


sub readfile {

### Read text from file ###
  my $file = $_[0];     
  my @words;

  open(TXT, "$file") or die $!;

  while (<TXT>) {
    chomp;
	s/  */ /g;
    s/ *$//g;
    s/^ */# /;                   # Add start-of-sentence token '#'
	s/$/ \<eos\>/;             # Add end-of-sentence token '<eos>'
    tr/A-ZÅÄÖ/a-zåäö/;
	
    push(@words, $_) foreach (split(' ', $_));
  }
  
  close(TXT);
  
  return @words;
}

sub getcounts {

### Collect n-gram counts ###

  my $count = 1;
  $wordhash{"<UNK>"} = 0;             # Give unknown tokens integer 0
  $wordhashrev{0} = "<UNK>";

#  foreach $n (0 .. 5) {
#	$wd = $words[$n];
  foreach $wd (@words) {
     if ($wd eq "") {
		print "word is empty\n";
 
	 }	 
    unless ( $wnum = $wordhash{$wd} ) {   # If word $wd isn't mapped to an integer in %wordhash, add it.
      $wnum = $count;
      $wordhash{$wd} = $count;
	  $wordhashrev{$count} = $wd;
      $count++;
    }     

    if ($old = $unigramcount{$wnum}) {    # Count unigrams 
      $unigramcount{$wnum} = $old + 1;
    } else {
      $unigramcount{$wnum} = 1;
    } 

    if ($oldnum) {                                
      if ($hashref = $bigramcount{$oldnum}) {          
	  ${$bigramcount{$oldnum}}{$wnum}++;   # Add count
      } else {                             
        my %hash;                             # Create new hash
        $hash{$wnum} = 1;                     # Add count for bigram "$oldnum $wnum"
        $bigramcount{$oldnum} = \%hash;       # Add a reference to the hash
      }
    } 
	
	if ($oldnum) {  
		my $bigram = "";
		if  ($oldnum == $wordhash{"#"}) {
			$bigram = "$oldnum $oldnum";
		} else {
			$bigram = "$oldoldnum $oldnum";
		}

		if ($hashref = $trigramcount{$bigram}) {          
			${ $trigramcount{$bigram}}{$wnum}++;   # Add count
		} else {                             
			my %hash;                             # Create new hash
			$hash{$wnum} = 1;                     # Add count for bigram "$oldnum $wnum"
			$trigramcount{$bigram} = \%hash;       # Add a reference to the hash
		}
	} else {
		$oldnum = $wordhash{"#"};
	}

	
	$oldoldnum = $oldnum;
    $oldnum = $wnum;   
	
  } 
}

sub log2 {
  # The following relationship holds for log of base N: 
  #   logN(x) = ln(x)/ln(N)
  #
  return log($_[0])/log(2);
}

sub generate_text{
  ## Generate sentences from the language model.
    my ($generate_sentences, $n) = @_;  
	my @sentence = ();
	if ($n eq "n1") { 
	    print "Genererar $generate_sentences meningar från en unigrammodell...\n\n";
		foreach (1..$generate_sentences) {
			@sentence = @{&generate_uni()};
			print &clean(\@sentence) . "\n";
		}
	} elsif ($n eq "n2") {
		print "Genererar $generate_sentences meningar från en bigrammodell...\n\n";
		foreach (1..$generate_sentences) {
			@sentence = @{&generate_bi()};
			print &clean(\@sentence) . "\n";
		}
	} elsif ($n eq "n3") {		
		print "Genererar $generate_sentences meningar från en trigrammodell...\n\n";
		foreach (1..$generate_sentences) {
			@sentence = @{&generate_tri()};
			print &clean(\@sentence) . "\n";
		}
	} else {
		"Ange språkmodell: n1, n2 eller n3\n";
	}
}

sub generate_bi {
	my $cwd = "#";
	my @sentence = ($cwd);

	while ($cwd ne "<eos>") { 
			$cn = $wordhash{$cwd};
			my %secondcount = %{$bigramcount{$cn}};
			my @sortedkeys = sort {$secondcount{$b} <=> $secondcount{$a}} keys %secondcount;
				
			my %randhash = ();
			my $start = 0;
			
			foreach $key (@sortedkeys) {    # foreach w2
			    #print "Current key: $key\n";
				my $w2ncount = $secondcount{$key};
				my $w2wd = $wordhashrev{$key};
				my $w2n = $key;
			    my $end = $start + $w2ncount; # 1 + 3, börja vid 4
				#print "$w2wd förekommer $w2ncount ggr\n";
				
				# Fördela orden i hashen
				foreach $k ($start .. $end) {
					#print "$k\t$w2wd\n";
					$randhash{$k} = $w2n;
					#print "Put $w2n at key $k\n";
				}
				$start = $end + 1;
				#print "Start: $start\n";
			}
						
			# Get second word
			my $random = &getrandom($start);
			#print "Random: $random\n";
			my $w2n = $randhash{$random};  # Ta ut rätt ord från randhash
			#print "Ordnr från randhash $w2n\n";
			my $w2wd = $wordhashrev{$w2n};
			#print "# $cwd $w2wd#\n";
			push(@sentence, $w2wd);
			#print "## @sentence\n";
			$cwd = $w2wd;
	}
	return \@sentence;
}

sub generate_tri {
	my $cwd1 = "#";
	my $cwd2 = "#";
	my $cwd = "$cwd1 $cwd2";
	my @sentence = ($cwd);
	#print "In tri, ord 1 = $cwd1 och ord 2 = $cwd2\n";
	
	while ($cwd2 ne "<eos>") { 
	#foreach (1..5) {
			$cn1 = $wordhash{$cwd1};
			$cn2 = $wordhash{$cwd2};
			$cn = "$cn1 $cn2";
			my %secondcount = %{$trigramcount{$cn}};
			#print "Cn: $cn Second: " . %secondcount . " \n";
			my @sortedkeys = sort {$secondcount{$b} <=> $secondcount{$a}} keys %secondcount;
				
			my %randhash = ();
			my $start = 0;
			
			foreach $key (@sortedkeys) {    # foreach w2
			    #print "Current key: $key\n";
				my $w2ncount = $secondcount{$key};
				my $w2wd = $wordhashrev{$key};
				my $w2n = $key;
			    my $end = $start + $w2ncount; # 1 + 3, börja vid 4
				#print "$w2wd förekommer $w2ncount ggr\n";
				
				# Fördela orden i hashen
				foreach $k ($start .. $end) {
					#print "$k\t$w2wd\n";
					$randhash{$k} = $w2n;
					#print "Put $w2n at key $k\n";
				}
				$start = $end + 1;
				#print "Start: $start\n";
			}
			# Get second word
			my $random = &getrandom($start);
			#print "Random: $random\n";
			my $w2n = $randhash{$random};  # Ta ut rätt ord från randhash
			#print "Ordnr från randhash $w2n\n";
			my $w2wd = $wordhashrev{$w2n};
			#print "# $cwd $w2wd#\n";
			push(@sentence, $w2wd);
			#print "## @sentence\n";
			$cwd1 = $cwd2;
			$cwd2 =	$w2wd;
	}
	return \@sentence;
}


sub generate_uni {
	my $cwd = "#";
	my @sentence = ($cwd);

	#print "In generate uni\n";
	while ($cwd ne "<eos>") { 
		#foreach (1..20) { 
			$cn = $wordhash{$cwd};
			my @sortedkeys = sort {$unigramcount{$b} <=> $unigramcount{$a}} keys %unigramcount;
				
			my %randhash = ();
			my $start = 0;
			
			foreach $key (@sortedkeys) {    # foreach w2
			    #print "Current key: $key\n";
				my $w2ncount = $unigramcount{$key};
				my $w2wd = $wordhashrev{$key};
				my $w2n = $key;
			    my $end = $start + $w2ncount; # 1 + 3, börja vid 4
				#print "$w2wd förekommer $w2ncount ggr\n";
				
				# Fördela orden i hashen
				foreach $k ($start .. $end) {
					#print "$k\t$w2wd\n";
					$randhash{$k} = $w2n;
					#print "Put $w2n at key $k\n";
				}
				$start = $end + 1;
				#print "Start: $start\n";
			}
						
			# Get second word
			my $random = &getrandom($start);
			#print "Random: $random\n";
			my $w2n = $randhash{$random};  # Ta ut rätt ord från randhash
			#print "Ordnr från randhash $w2n\n";
			my $w2wd = $wordhashrev{$w2n};
			#print "# $cwd $w2wd#\n";
			push(@sentence, $w2wd);
			#print "## @sentence\n";
			$cwd = $w2wd;
	}
	return \@sentence;
}

sub clean {
	my @sentence = @{$_[0]};
	pop(@sentence);
	shift(@sentence);
	my $string = join(' ',@sentence) ;
	$string =~ s/&quot;/\"/g;
	$string =~ s/ # / /g;
	@string = split(//, $string);
	$string[0] =~ tr/a-zåäöé]/A-ZÅÄÖÉ/;
	return join('', @string);
}

sub getrandom {
	my $start = shift;
	my $random = int( rand($start)) + 0; # Slumpa fram ett tal från 0 till $start
	#print "Random: $random\n";
			
	return $random;		
}

