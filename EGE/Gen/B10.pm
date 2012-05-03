# Copyright © 2010-2011 Alexander S. Klenin
# Copyright © 2012 V. Kevroletin
# Licensed under GPL version 2 or later.
# http://github.com/klenin/EGE
package EGE::Gen::B10;
use base 'EGE::GenBase::DirectInput';

use strict;
use warnings;
use utf8;

use EGE::Random;
use EGE::NumText;
use List::Util 'max';


sub _num_with_unit {
    my ($num) = @_;
    my @units = qw(байт Кбайт Мбайт Гбайт Тбайт);
    my $i = 0;
    while ($num && $num % 1024 == 0) {
        $num = int($num / 1024);
        ++$i
    }
    $num . ' ' . $units[$i]
}

sub data_transmittion {
    my ($self) = @_;
    my $v1_bin_pow = rnd->in_range(14, 20);
    my $v2_bin_pow = rnd->in_range(10, 13);

    my $data_size_byte =
        rnd->in_range(1, 9) * 2**rnd->in_range($v2_bin_pow, $v2_bin_pow + 10);
    my $buff_size_byte =
        rnd->in_range(1, 9) * 2**rnd->in_range($v1_bin_pow, $v1_bin_pow + 5);
    $data_size_byte = max($data_size_byte, $buff_size_byte);

    $self->{correct} =  $buff_size_byte*8 / 2**$v1_bin_pow +
                        $data_size_byte*8 / 2**$v2_bin_pow;

    my ($data_size_text, $buff_size_text) =
        map { sprintf "<strong>%s</strong>", _num_with_unit($_) }
         $data_size_byte, $buff_size_byte;
    my $to_hash = sub {
        my ($x) = @_;
        my %h;
        $h{$_} = shift @$x for qw(gender nominative dative genitive instrumental);
        \%h
    };
    my ($name1, $name2) = rnd->pick_n(2,
        map { $to_hash->($_) }
            [qw(ж Катя Кате Кати Катей)],
            [qw(м Сергей Сергею Сергея Сергеем)]
    );

    my $pronoun1 = {м => 'он', ж => 'она'}->{$name1->{gender}};
    my $pronoun2 = {м => 'него', ж => 'неё'}->{$name2->{gender}};
    my $action = {м => 'договорился', ж => 'договорилась'}->{$name2->{gender}};
    $self->{text} = <<EOL
У $name1->{genitive} есть доступ в Интернет по высокоскоростному одностороннему
радиоканалу, обеспечивающему скорость получения информации <strong>2<sup>$v1_bin_pow</sup></strong>
бит в секунду. У $name2->{genitive} нет скоростного доступа в Интернет, но есть
возможность получать информацию от $name1->{genitive} по телефонному каналу со
средней скоростью <strong>2<sup>$v2_bin_pow</sup></strong> бит в секунду.
$name2->{nominative} $action с $name1->{instrumental}, что $pronoun1 скачает для $pronoun2
данные объёмом $data_size_text по высокоскоростному каналу и ретранслирует их
$name2->{genitive} по низкоскоростному каналу. Компьютер $name1->{genitive}
может начать ретрансляцию данных не раньше, чем им будут получены первые
$buff_size_text этих данных. Каков минимально возможный промежуток времени
(в секундах) с момента начала скачивания $name1->{instrumental} данных до полного
их получения $name2->{instrumental}? В ответе укажите только число, слово
«секунд» или букву «с» добавлять не нужно.
EOL
}

1;
