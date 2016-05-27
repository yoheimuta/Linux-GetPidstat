requires 'perl', '5.008001';
requires 'Parallel::ForkManager', '==1.17';
requires 'WebService::Mackerel', '==0.03';
requires 'IO::Socket::SSL', '==2.024';

on 'test' => sub {
    requires 'Test::More', '0.98';
};

