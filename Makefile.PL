# This -*- perl -*- script writes the Makefile by ukai
#
# perl Makefile.pl
# make
# make install or make install_rpop
#
require 5.004;

BEGIN {
$VERSION = '76';
$im_version="version 971024";
$im_revised="Oct 24, 1997";
$im_db_type="DB";

# this should be in BEGIN section.
if ($im_db_type) {
    @AnyDBM_File::ISA = qw(DB_File GDBM_File NDBM_File SDBM_File ODBM_File);
    unshift(@AnyDBM_File::ISA, "${im_db_type}_File");
    print "try DB type: @AnyDBM_File::ISA\n";
} else {
    print "ignore DB type\n";
}
}

use Config;

$prefix = "/usr/local";
$libdir = "\$exec_prefix/lib";

if (open(CONFIN, "configure.in")) {
    while (<CONFIN>) {
	/^im_cv/ && eval "\$$_";
    }
    close(CONFIN);
}
# print "$im_version, $im_revised\n";

# checking DB type
if ($im_db_type) {
    use AnyDBM_File;
    $im_db_type="$AnyDBM_File::ISA[0]";
    $im_db_type =~ s/_File$//;
    print "Your DB type is $im_db_type\n";
}
# generate im*.in -> im*.PL
opendir(DIR, ".") or die "cannot opendir .: $!";
@programs_to_install = @pl_files = ();
foreach (grep(/\.in$/ && !/^(configure|Makefile|IM)/, readdir DIR)) {
    open(IN, "$_") or die "cannot open $_.in: $!";
    s/.in$//;
    push(@programs_to_install, "$_");
    open(PL, ">$_.PL") or die "cannot open $_.PL: $!";
    push(@pl_files, "$_.PL");
    print PL <<"!SUBST!";
use Config;
(\$file = \$0) =~ s/\\.PL\$//i;
open(OUT, ">\$file") or die "Cannot create \$file: $!";
chmod(0755, \$file);
print "Extracting \$file (with variable substitutions)\n";
print OUT << \"!GROK!THIS\";
\$Config{'startperl'}

!GROK!THIS
while (<DATA>) {
    /^#! \\\@im_path_perl\\\@/ && next;
    s/\\\@im_version\\\@/$im_version/;
    s/\\\@im_revised\\\@/$im_revised/;
    print OUT;
}
close(OUT);
exit 0;
__END__
!SUBST!
    while (<IN>) {
	print PL $_;
    }
    close(IN);
    close(PL);
}
closedir(DIR);


# generate IM.in/*.pm.in -> IM/*.pm
@modules_files = ();
opendir(DIR, "IM.in") or die "cannot opendir IM.in: $!";
foreach (grep(/\.in$/, readdir DIR)) {
    open(IN, "IM.in/$_") or die "cannot open IM.in/$_: $!";
    s/\.in$//;
    open(PM, ">IM/$_") or die "cannot open IM/$_: $!";
    push(@modules_files, "IM/$_");
    print "Extracting IM/$_ (with variable substitutions)\n";
    while (<IN>) {
	s/\@im_version\@/$im_version/;
	s/\@im_revised\@/$im_revised/;
	s/\@im_db_type\@/$im_db_type/;
	s/\@prefix\@/$prefix/;	# Config.pm.in
	s/\@libdir\@/$libdir/;	# Config.pm.in
	print PM;
    }
    close(IN);
    close(PM);
}
closedir(DIR);

# write Makefile
use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME' => 'IM',
    'VERSION' => $VERSION,
    'EXE_FILES' => \@programs_to_install,
    'MAN1PODS' => {},
    'MAN3PODS' => {},
    'clean' => { FILES => join(' ', '$(EXE_FILES)', 
			       @pl_files, @modules_files) },
    'dist' => { COMPRESS => 'gzip -9f', SUFFIX => 'gz' }
); 


# special rules
sub MY::postamble {
    my ($self) = shift;
    my (@m);
    push (@m, qq{
prefix=$prefix
exec_prefix=$prefix
libdir=\$(exec_prefix)/lib
IM_SITECONFIG_DIR=\$(libdir)/im

install:: install_config

install_config: cnf.im/SiteConfig
	\$(MKPATH) \$(IM_SITECONFIG_DIR)
	for cnf_im in SiteConfig ; do \\
	    if \$(TEST_F) \$(IM_SITECONFIG_DIR)/\$\$cnf_im; then \\
		(\$(CP) cnf.im/\$\$cnf_im \$(IM_SITECONFIG_DIR)/\$\$cnf_im.new;) \\
	    else \\
		(\$(CP) cnf.im/\$\$cnf_im \$(IM_SITECONFIG_DIR);) \\
	    fi \\
	done
	\$(CHMOD) -R 0644 \$(IM_SITECONFIG_DIR)/*
	\$(CHMOD) 755 \$(IM_SITECONFIG_DIR)

uninstall:: uninstall_config

uninstall_config::
	\$(RM_F) \$(IM_SITECONFIG_DIR)/Config
	\$(RM_F) \$(IM_SITECONFIG_DIR)/SiteConfig

install_rpop: install
	\$(PERL) -e 'chown(0, (getgrnam("mail"))[2], \@ARGV) and chmod(04555, \@ARGV);' \$(INSTALLSCRIPT)/imget
    });
    join "", @m;
}


