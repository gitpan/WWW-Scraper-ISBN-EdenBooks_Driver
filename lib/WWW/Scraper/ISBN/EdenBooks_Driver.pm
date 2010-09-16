package WWW::Scraper::ISBN::EdenBooks_Driver;

use strict;
use warnings;

use vars qw($VERSION @ISA);
$VERSION = '0.02';

#--------------------------------------------------------------------------

=head1 NAME

WWW::Scraper::ISBN::EdenBooks_Driver - Search driver for Eden Books online book catalog.

=head1 SYNOPSIS

See parent class documentation (L<WWW::Scraper::ISBN::Driver>)

=head1 DESCRIPTION

Searches for book information from Eden Books online book catalog

=cut

#--------------------------------------------------------------------------

###########################################################################
# Inheritence

use base qw(WWW::Scraper::ISBN::Driver);

###########################################################################
# Modules

use WWW::Mechanize;

###########################################################################
# Constants

use constant	SEARCH	=> 'http://www.edenbookshop.co.uk/books/browse.php?keyword=';
my ($URL1) = ('http://www.edenbookshop.co.uk/books/[^"]+-\d+.html');

#--------------------------------------------------------------------------

###########################################################################
# Public Interface

=head1 METHODS

=over 4

=item C<search()>

Creates a query string, then passes the appropriate form fields to the EdenBooks
server.

The returned page should be the correct catalog page for that ISBN. If not the
function returns zero and allows the next driver in the chain to have a go. If
a valid page is returned, the following fields are returned via the book hash:

  isbn          (now returns isbn13)
  isbn10        
  isbn13
  ean13         (industry name)
  author
  title
  book_link
  image_link
  description
  pubdate
  publisher
  binding       (if known)
  pages         (if known)
  weight        (if known) (in grammes)
  width         (if known) (in millimetres)
  height        (if known) (in millimetres)

The book_link and image_link refer back to the EdenBooks website.

=back

=cut

sub search {
	my $self = shift;
	my $isbn = shift;
	$self->found(0);
	$self->book(undef);

	my $mech = WWW::Mechanize->new();
    $mech->agent_alias( 'Linux Mozilla' );

    eval { $mech->get( SEARCH . $isbn ) };
    return $self->handler("EdenBooks website appears to be unavailable.")
	    if($@ || !$mech->success() || !$mech->content());

    my $content = $mech->content;
    my ($link) = $content =~ m!"($URL1)"!s;
#print STDERR "\n# content1=[\n$content\n]\n";
#print STDERR "\n# link=[$link]\n";

	return $self->handler("Failed to find that book on EdenBooks website.")
	    unless($link);

    eval { $mech->get( $link ) };
    return $self->handler("EdenBooks website appears to be unavailable.")
	    if($@ || !$mech->success() || !$mech->content());

	# The Book page
    my $html = $mech->content();

	return $self->handler("Failed to find that book on EdenBooks website. [$isbn]")
		if($html =~ m!Sorry, we couldn't find any matches for!si);
    
#print STDERR "\n# content2=[\n$html\n]\n";

    my $data;
    ($data->{publisher})                = $html =~ m!<tr><td class="definition">Publisher</td><td>([^<]+)</td></tr>!si;
    ($data->{pubdate})                  = $html =~ m!<tr><td class="definition">Date Published</td><td>([^<]+)</td></tr>!si;
    ($data->{image})                    = $html =~ m!(http://www.eden.co.uk/images/300/\d+.jpg)!si;
    ($data->{thumb})                    = $html =~ m!(http://www.eden.co.uk/images/150/\d+.jpg)!si;
    ($data->{isbn13})                   = $html =~ m!<tr><td class="definition">ISBN</td><td>(\d+)</td></tr>!si;
    ($data->{isbn10})                   = $html =~ m!<tr><td class="definition">ISBN-10</td><td>(\d+)</td></tr>!si;
    ($data->{author})                   = $html =~ m!<tr><td class="definition">Author</td><td><a href="[^"]+">([^<]+)</a></td></tr>!si;
    ($data->{title})                    = $html =~ m{<!-- Product Information -->\s*<h1>([^<]+)</h1>}si;
    ($data->{description})              = $html =~ m!<h2>About[^<]+</h2>\s*<p>([^<]+)!si;
    ($data->{binding})                  = $html =~ m!<tr><td class="definition">Book Format</td><td>([^<]+)!si;
    ($data->{pages})                    = $html =~ m!<tr><td class="definition">Number of Pages</td><td>([\d.]+)</td></tr>!si;
    ($data->{weight})                   = $html =~ m!<tr><td class="definition">Weight</td><td>([\d.]+)\s*g</td></tr>!si;
    ($data->{width})                    = $html =~ m!<tr><td class="definition">Width</td><td>([\d.]+)\s*mm</td></tr>!si;
    ($data->{height})                   = $html =~ m!<tr><td class="definition">Height</td><td>([\d.]+)\s*mm</td></tr>!si;

    $data->{author} =~ s!<[^>]+>!!g;
    $data->{description} =~ s!<div.*?</div>!!s;
    $data->{description} =~ s!<a .*!!s;
    $data->{description} =~ s!</?b>!!g;
    $data->{description} =~ s!<br\s*/>!\n!g;
    $data->{description} =~ s! +$!!gm;
    $data->{description} =~ s!\n\n!\n!gs;

#use Data::Dumper;
#print STDERR "\n# " . Dumper($data);

	return $self->handler("Could not extract data from EdenBooks result page.")
		unless(defined $data);

	# trim top and tail
	foreach (keys %$data) { next unless(defined $data->{$_});$data->{$_} =~ s/^\s+//;$data->{$_} =~ s/\s+$//; }

	my $bk = {
		'ean13'		    => $data->{isbn13},
		'isbn13'		=> $data->{isbn13},
		'isbn10'		=> $data->{isbn10},
		'isbn'			=> $data->{isbn13},
		'author'		=> $data->{author},
		'title'			=> $data->{title},
		'book_link'		=> $mech->uri(),
		'image_link'	=> $data->{image},
		'thumb_link'	=> $data->{thumb},
		'description'	=> $data->{description},
		'pubdate'		=> $data->{pubdate},
		'publisher'		=> $data->{publisher},
		'binding'	    => $data->{binding},
		'pages'		    => $data->{pages},
		'weight'		=> $data->{weight},
		'width'		    => $data->{width},
		'height'		=> $data->{height}
	};

#use Data::Dumper;
#print STDERR "\n# book=".Dumper($bk);

    $self->book($bk);
	$self->found(1);
	return $self->book;
}

1;

__END__

=head1 REQUIRES

Requires the following modules be installed:

L<WWW::Scraper::ISBN::Driver>,
L<WWW::Mechanize>

=head1 SEE ALSO

L<WWW::Scraper::ISBN>,
L<WWW::Scraper::ISBN::Record>,
L<WWW::Scraper::ISBN::Driver>

=head1 BUGS, PATCHES & FIXES

There are no known bugs at the time of this release. However, if you spot a
bug or are experiencing difficulties that are not explained within the POD
documentation, please send an email to barbie@cpan.org or submit a bug to the
RT system (http://rt.cpan.org/Public/Dist/Display.html?Name=WWW-Scraper-ISBN-EdenBooks_Driver).
However, it would help greatly if you are able to pinpoint problems or even
supply a patch.

Fixes are dependant upon their severity and my availablity. Should a fix not
be forthcoming, please feel free to (politely) remind me.

=head1 AUTHOR

  Barbie, <barbie@cpan.org>
  Miss Barbell Productions, <http://www.missbarbell.co.uk/>

=head1 COPYRIGHT & LICENSE

  Copyright (C) 2010 Barbie for Miss Barbell Productions

  This module is free software; you can redistribute it and/or
  modify it under the Artistic Licence v2.

=cut
