#!/usr/bin/perl
# ngram.pl
# Creates a bigram model using add_x smoothing.
# Also contains functions for computing cross-perplexity on a 
# test-set.
#
# Run:
#  ngram.pl N  train.txt test.txt
# 
# where N is the smoothing constant, default i N=1 (add-one smoothing)
#
# by Maria Holmqvist 2008

## Variable declarations 
my $smoothing = $ARGV[0];      # Smoothing constant for add_x smoothing (Default is add 1 to each ngram count)
my $trainfile = $ARGV[1];      # Build language model from this text
my $testfile = $ARGV[2];       # Evaluate language model on this text  

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

my %unigrammodel = ();  # Hash containing unigram-probabilities (structured as above)
my %bigrammodel = ();   # Hash containing bigram-probabilities (structured as above)

## "Main" part of program
my @words = &readfile($trainfile);    # Get a list of words in training text
# Build model
&getcounts;                           # Count bigrams and unigrams

if ($smoothing eq "wb") {   
  &witten_bell;     
} else {
  &add_x($smoothing);               # Calculate probabilities and smoothing values   
}

&evaluate($testfile);                # Test bigrammodel on test data


#################
#               
#  Subroutines:  
#               
#################

### Calculate WITTEN-BELL smoothed bigrammodel ###

sub witten_bell {  
  my @wordtypes = keys(%unigramcount);
  my $v = @wordtypes;

  %bigrammodel = ();
  print "Creating bigrammodel using Witten-Bell smoothing\n"; 

  foreach $first (@wordtypes){  
#   print "First wordtype: $type1\n";
    my %hash;
    my %secondhash = %{$bigramcount{$first}};
    my $t = keys(%secondhash);
    my $n = 0;

    foreach $second (keys(%secondhash)) {
      # Calculating probability for bigram "$first $second"
      $hash{$second} = log2 ($secondhash{$second}/($unigramcount{$first} + $t));
      $n = $n + $secondhash{$second};
    }

    my $z = $v - $t;
 #   print "Z($type1): $z\t  V:$v - T($type1):$t\n";
    $hash{"smooth"} = log2 ( $t / ($z * ($n + $t)));

    ## $hash{0} = log2 ( 1/($unigramcount{$type1} + $v));  ## <UNK>
    $bigrammodel{$first} = \%hash;  

  }
}

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

  print "Creating bigrammodel using add_x smoothing, x = $add\n"; 

  %bigrammodel = ();

  foreach $word1 (@wordtypes) {
    my %secondhash = %{ $bigramcount{$word1} };   # $bigramcount{$word1} contains a reference to a hash
                                                  # The hash is de-referenced using: %{ <reference> }
    my %hash;                                     # Create hash for probabilities
    
    foreach $word2 (keys(%secondhash)) {   
      # Calculating probability for bigram "$word1 $word2"
      $hash{$word2} = log2 (($secondhash{$word2} + $add)/($unigramcount{$word1} + $add * $types));
    }

	$prob = ($unigramcount{$word1} + $add * $types);
	#die "zero probability" if ($prob == 0) ;
	
	
    $hash{"smooth"} = log2 ($add / ($unigramcount{$word1} + $add * $types));   # Add smoothing value for unseen bigrams "word1 X"
    $bigrammodel{$word1} = \%hash;                                             # Add a reference to %hash
  } 
 
  my %hash;
  $hash{"smooth"} = log2 ( $add/($add + $types * $add) );          ## Smoothing value for bigrams starting with unknown word
  $bigrammodel{0} = \%hash; 
}

### Calculate Cross-perplexity on text $txt ###

sub evaluate {
  my $filename = $_[0];
  my @words = ();

  print "Evaluation of model on $filename\n";

  open(TEST, "$filename") or die $!;

  while (<TEST>) {
    chomp;
    s/ *$//g;
    s/^ */# /;
    tr/A-ZÅÄÖ/a-zåäö/;
    foreach $word (split(' ', $_)) {
      if ($num = $wordhash{$word}) {
	push(@words, $num);            # Map words to integers according to %wordhash
      } else {
	push(@words, 0);               # Map word to 0 if it is unknown
      }
    }
  }

  close(TEST);
  $modelprob = 0;

  #
  # Calculate probability for the entire test text

  for (my $i = 0; $i + 1 < @words; $i++) {
    my $numb = @words;

    $current = $words[$i];
    $next = $words[$i+1];

    if (%second = %{$bigrammodel{$current}}) {
      if ($second{$next}) {
	$modelprob = $modelprob + $second{$next};         # log x + log y = log (x * y) 
      } else {
	$modelprob = $modelprob + $second{"smooth"};
      }
    } 
  }

  print "Logprob: $modelprob\n";
  ##print "Cross-Entropy: " . -($modelprob/@words) . "\n";
  print "Perplexity: " . 2**-($modelprob/@words) . "\n";
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
	${ $bigramcount{$oldnum}}{$wnum}++;   # Add count
      } else {                             
        my %hash;                             # Create new hash
        $hash{$wnum} = 1;                     # Add count for bigram "$oldnum $wnum"
        $bigramcount{$oldnum} = \%hash;       # Add a reference to the hash
      }
    } 
    
    $oldnum = $wnum;   
  } 
}

sub log2 {
  # The following relationship holds for log of base N: 
  #   logN(x) = ln(x)/ln(N)
  #
  return log($_[0])/log(2);
}
