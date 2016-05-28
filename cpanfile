requires 'perl', '5.008001';
requires 'Parallel::ForkManager', '==1.17';
requires 'WebService::Mackerel', '==0.03';
requires 'IO::Socket::SSL', '==2.024';
requires 'Capture::Tiny', '== 0.40';
requires 'Data::Section::Simple', '== 0.07';

on 'test' => sub {
    requires 'Test::More', '0.98';
    requires 'Test::Mock::Guard', '0.10';
};

