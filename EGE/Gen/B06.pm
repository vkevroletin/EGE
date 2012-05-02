# Copyright © 2010-2011 Alexander S. Klenin
# Copyright © 2011 V. Kevroletin
# Licensed under GPL version 2 or later.
# http://github.com/klenin/EGE
package EGE::Gen::B06;
use base 'EGE::GenBase::DirectInput';
use v5.10;

use strict;
use warnings;
use utf8;

use EGE::Random;
use EGE::Russian::Names;
use EGE::Russian::Jobs;
use Data::Dumper;

use Storable qw(dclone);

my %relations = ( ToRight     => { v => {}, is_sym => 0 },
                  Together    => { v => {}, is_sym => 1 },
                  NotTogether => { v => {}, is_sym => 1 },
                  PosLeft     => { v => {}, is_sym => 0 },
                  PosRight    => { v => {}, is_sym => 0 },
                  Pos         => { v => {}, is_sym => 0 },
                  NotPos      => { v => {}, is_sym => 0 } );

sub all_perm {
    my $rec;
    $rec = sub {
        my ($curr_res, $tot_res, @elems) = @_;
        unless (@elems) {
            push @{$tot_res}, $curr_res;
            return;
        }
        for my $i (0 .. $#elems) {
            $rec->([@$curr_res, $elems[$i]], $tot_res,
                   (@elems[0 .. $i - 1], @elems[$i + 1 .. $#elems]));
        }
    };
    my $res = [];
    $rec->([], $res, @_);
    $res;
}

sub unique_pairs {
    my ($n) = @_;
    my @res;
    for my $i (0 .. $n - 1) {
        for my $j ($i + 1 .. $n - 1) {
            push @res, [$i, $j];
        }
    }
    @res;
}

sub all_pairs {
    my ($n) = @_;
    my @res;
    for my $i (0 .. $n - 1) {
        for my $j (0 .. $n - 1) {
            push @res, [$i, $j];
        }
    }
    @res;
}

sub relation_clear_all {
    for (keys %relations) {
        $relations{$_}->{v} = { 0 => {}, 1 => {}, 2 => {}, 3 => {} };
    }
}

sub relation_add {
    my ($i, $j, $r) = @_;
    $relations{$r}->{v}->{$i}{$j} = 1;
    $relations{$r}->{v}->{$j}{$i} = 1 if $relations{$r}->{is_sym};
}

sub relation_rm {
    my ($i, $j, $r) = @_;
    delete $relations{$r}->{v}->{$i}{$j};
    delete $relations{$r}->{v}->{$j}{$i} if $relations{$r}->{is_sym};
}

sub check {
    my ($c) = @_;

    my %pos = map { $c->[$_] => $_ } 0 .. 3;

    for my $i (1 .. $#{$c} - 1) {
        my ($pred, $curr, $nxt) = @{$c}[$i-1 .. $i+1];
        for (keys %{$relations{Together}->{v}->{$curr}}) {
            unless ($_ == $pred || $_ == $nxt) {
                return 0;
            }
        }
        if ($relations{NotTogether}->{v}->{$curr}{$pred} ||
            $relations{NotTogether}->{v}->{$curr}{$nxt}) {
            return 0;
        }
    }

    for my $i (0 .. $#{$c}) {
        my $curr = $c->[$i];
        for (keys %{$relations{ToRight}->{v}->{$curr}}) {
            return 0 if $i <= $pos{$_};
        }
        for (keys %{$relations{PosLeft}->{v}->{$curr}}) {
            return 0 if $_ <= $i;
        }
        for (keys %{$relations{PosRight}->{v}->{$curr}}) {
            return 0 if $_ >= $i;
        }
        for (keys %{$relations{Pos}->{v}->{$curr}}) {
            return 0 if $_ != $i;
        }
        for (keys %{$relations{NotPos}->{v}->{$curr}}) {
            return 0 if $_ == $i;
        }
    }
    1;
}

sub filter {
    my ($perm) = @_;
    grep { check($_) } @$perm;
}

sub try_new_cond {
    my ($cond, $answers) = @_;
    relation_add(@$cond);
    my @new_ans = filter($answers);
    if (@new_ans == @$answers || !@new_ans) {
        relation_rm(@$cond);
    } else {
        @$answers = @new_ans;
    }
    return @new_ans == 1;
}

sub create_init_cond {
    # создать ограничения "правее": важно, чтобы не было циклов
    my ($cnt) = @_;
    relation_clear_all();
    my @edges = rnd->pick_n($cnt, unique_pairs(4) );
    for (@edges) {
        my ($i, $j) = @$_;
        $relations{ToRight}->{v}->{$j}{$i} = 1;
    }
}

sub create_cond {
    our (@relations) = @_;
    sub make_pairs {
        my @pairs;
        for my $rel (@relations) {
            my @tmp = $relations{$rel}->{is_sym} ?
                          unique_pairs(4) : all_pairs(4);
            push @pairs, [@$_, $rel] for @tmp;
        }
        rnd->shuffle(@pairs);
    }
    my @pairs = make_pairs();
    create_init_cond(rnd->pick(2, 2, 3));
    my @answers = filter( all_perm(0 .. 3) );
    my $ok = !@answers;
    while (!$ok) {
        $ok |= try_new_cond(pop @pairs, \@answers);
        @pairs = make_pairs unless @pairs;
    }
    clear_cond();
    @{$answers[0]};
}

sub clear_cond {
    my $var = all_perm(0 .. 3);
    my $ans_orig = filter($var);
    my $ok = 1;
    while ($ok) {
        $ok = 0;
        for my $rel (keys %relations) {
            for my $i (0 .. 3) {
#                for my $j (keys %{$relations->{$rel}->{v}->{$i}}) {
                for my $j (keys %{$relations{$rel}->{v}->{$i}}) {
                    relation_rm($i, $j, $rel);
                    if (filter($var) != $ans_orig) {
                        relation_add($i, $j, $rel);
                    } else {
                        $ok = 1;
                    }
                }
            }
        }
    }
}

sub create_questions {
    my ($descr) = @_;
    my @cond;
    for my $key (keys %relations) {
        my $rel = $relations{$key};
        for my $i (keys %{$rel->{v}}) {
            for my $j (keys %{$rel->{v}->{$i}}) {
                if (!$rel->{is_sym} || $i > $j) {
                    push @cond, $descr->{$key}->($i, $j)
                }
            }
        }
    }
    @cond;
}

sub genitive { # родительный падеж
    my $name = shift;
    if ($name =~/й$/) { $name =~ s/й$/я/ }
    elsif ($name =~ /ь$/) { $name =~ s/ь$/я/ }
    else { $name .= 'а' };
    $name;
}

sub ablative { # творительный падеж
    my $name = shift;
    if ($name =~ /й$/) { $name =~ s/й$/ем/ }
    elsif ($name =~ /ь$/) { $name =~ s/ь$/ем/ }
    else { $name .= 'ом' };
    $name;
}

sub on_right {
    given (rnd->in_range(0, 3)) {
        when (0) { return "$_[1] живет левее  " . genitive($_[0]) }
        when (1) { return "$_[0] живёт правее " . genitive($_[1]) }
        when (2) { return "$_[1] живет левее, чем  " . $_[0] }
        when (3) { return "$_[0] живёт правее, чем " . $_[1] }
    }
 }

sub together {
    "$_[0] живёт рядом " . "c " . ablative($_[1]);
}

sub not_together {
    "$_[0] живёт не рядом " . "c " . ablative($_[1]);
}

sub solve {
    my ($self) = @_;
    my @names = EGE::Russian::Names::different_males(4);
    my @prof = EGE::Russian::Jobs::different_jobs(4);

    my @prof_order = create_cond('Together', 'NotTogether');

    my %descr = (
        ToRight => sub { on_right($prof[$_[0]], $prof[$_[1]]) },
        Together => sub { together($prof[$_[0]], $prof[$_[1]]) },
        NotTogether => sub { not_together($prof[$_[0]], $prof[$_[1]]) }
    );
    my @questions = create_questions(\%descr);

    my @ans = create_cond(keys %relations);

    %descr = (
        ToRight => sub { on_right($names[$_[0]], $names[$_[1]]) },
        Together => sub { together($names[$_[0]], $names[$_[1]]) },
        NotTogether => sub { not_together($names[$_[0]], $names[$_[1]]) },
        PosLeft => sub { on_right($prof[$prof_order[$_[1]]], $names[$_[0]]) },
        PosRight => sub { on_right($names[$_[0]], $prof[$prof_order[$_[1]]]) },
        Pos => sub { "$names[$_[0]] работает " .
                     ablative($prof[$prof_order[$_[1]]]) },
        NotPos => sub { "$names[$_[0]] не работает " .
                        ablative($prof[$prof_order[$_[1]]]) }
    );
    @questions = (@questions, create_questions(\%descr));

    $self->{text} =
      "На одной улице стоят в ряд 4 дома, в которых живут 4 человека: " .
      (join ", ", map "<strong>$_</strong>", @names) .
      ". Известно, что каждый из них владеет ровно одной из следующих профессий: " .
      (join ", ", map "<strong>$_</strong>", @prof) .
      ", но неизвестно, кто какой и неизвестно, кто в каком доме живет. Однако, " .
      "известно, что:<br/>";

    $self->{text} .= "<ol>";
    $self->{text} .= "<li>$_</li>" for rnd->shuffle(@questions);
    $self->{text} .= "</ol>";

    my @example = rnd->shuffle(@names);
    $self->{text} .=
      "Выясните, кто какой профессии, и кто где живет, и дайте ответ в виде " .
      "заглавных букв имени людей, в порядке слева направо. Например, если бы " .
      "в домах жили (слева направо) " . (join ", ", @example) .
      ", ответ был бы: " . join '', map substr($_, 0, 1), @example;

    $self->{correct} = join '',  map { substr($names[$_], 0, 1) } @ans;
}

sub _lin_comb {
    my ($c1, $c2) = @_;
    if ($c1 < 0 && $c2 > 0) {
        ($a, $b, $c1, $c2) = ('b', 'a', $c2, $c1)
    } else {
        ($a, $b) = ('a', 'b')
    }
    [($c2 > 0 ? '+' : '-'),
        ($c1 == 1 ? $a : $c1 == -1 ? ['-', $a] : ['*', $c1, $a]),
        (abs($c2) == 1 ? $b : ['*', abs($c2), $b])]
}

sub _rand_lin_comb {
    _lin_comb((rnd->coin() ? 1 : -1) * rnd->in_range(1, 2),
              (rnd->coin() ? 1 : -1) * rnd->in_range(1, 2))
}

sub arith_with_if {
    my ($self) = @_;
    my ($a_val, $b_val) = map { rnd->in_range(-10, 10)*10 } 1, 2;
    my $op = rnd->pick('>', '>=', '<', '<=', '==', '!=');
    my ($lc1, $lc2); do {
        ($lc1, $lc2) = map { _rand_lin_comb() } 1, 2
    } while ($lc1 == $lc2);
    $b = EGE::Prog::make_block([
        '=', 'a', $a_val,
        '=', 'b', $b_val,
        '=', (rnd->coin() ? 'a' : 'b'), _rand_lin_comb(),
        'if_else', [$op, 'a', 'b'], [
            '=', 'c', $lc1
        ], [
            '=', 'c', $lc2
        ],
    ]);
    $self->{correct} = $b->run_val('c');
    my $lt = EGE::LangTable::table($b, [ [ 'Basic', 'Pascal' ], [ 'C', 'Alg', 'Perl' ] ]);
    $self->{text} = 'Определите значение переменной <strong>c</strong> после ' .
        'выполнения следующего фрагмента программы (записанного ниже на ' .
        'разных языках программирования).' . $lt;
}

1;
