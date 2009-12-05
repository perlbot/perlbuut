use 5.008008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

# path where the shared library libj601.so resides
$jlibpath = "/home/ambrus/local/lib";

WriteMakefile(
    NAME              => 'Jplugin',
    VERSION_FROM      => 'lib/Jplugin.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Jplugin.pm', # retrieve abstract from module
       AUTHOR         => 'Zsban Ambrus <ambrus@math.bme.hu>') : ()),
    LIBS              => ['-lj'], # e.g., '-lm'
    DEFINE            => '', # e.g., '-DHAVE_SOMETHING'
    INC               => '-I.', # e.g., '-I. -I/usr/include/other'
	# Un-comment this if you add C files to link with later:
    # OBJECT            => '$(O_FILES)', # link all the C files too
);
