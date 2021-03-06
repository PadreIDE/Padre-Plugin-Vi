package Vimper::SyntaxDag::Group;

use 5.010;
use Moose;
use Moose::Autobox;
use MooseX::Method::Signatures;
use MooseX::Has::Sugar;
use Graph;
use Graph::Writer::Dot;
use MooseX::Types::Moose qw(HashRef ArrayRef Str);
use aliased 'Vimper::CommandSheet';
use aliased 'Vimper::Command::Normal' => 'NormalCommand';
use aliased 'Vimper::SyntaxPath';
use aliased 'Vimper::SyntaxPath::Node';

# two commands are in the same syntax group if they have the same
# syntax paths- e.g. "h" and "j" are in the same group, but "f" is
# in a different group
# all commands in a group have the same DAG, and this class models
# that DAG
# we build the graph of the group by adding all the possible syntax
# paths of all commands in the group to the graph
# the resulting DAG could be used for many wonderful things

has name   => (ro, required  , isa => Str);
has src    => (ro, required  , isa => ArrayRef[NormalCommand]);
has dag    => (ro, lazy_build, isa => 'Graph', handles => [qw(vertices
                                                              predecessors
                                                              set_vertex_attribute
                                                              get_vertex_attribute
                                                              get_label
                                                              set_label
                                                              append_to_label
                                                              add_vertex
                                                              has_vertex
                                                              add_edge
                                                              has_edge)]);

method _build_dag { Graph->new(directed => 1) }

my $IDX = 0;

method BUILD { $self->add_command($_) for $self->src->flatten }

method some_command    { $self->src->[0] }
method syntax_group    { $self->some_command->syntax_group }
method count_node_kind { $self->some_command->count_node_kind }
method key1_node_kind  { $self->some_command->key1_node_kind }

method graph {
    my $name = 'dot_out/'. ($IDX++). '.dot';
    my $w = Graph::Writer::Dot->new;
    $w->write_graph($self->dag, $name);
    system("'/c/Program Files/Graphviz2.26.3/bin/dot.exe' -Tpng -O $name")
        && die "Can't graphviz";
}

method add_command(NormalCommand $command)
    { $self->add_path($_) for $command->syntax_paths->flatten }

method add_path(SyntaxPath $path) {
    my $prev_path_node;
    for my $path_node ($path->parts->flatten) {

        # dont show command nodes        
        # next if $path_node->type eq 'command';

        my $node      = escape($path_node->graph_name);
        my $label     = escape($path_node->graph_label);
        my $bag_key   = $path_node->bag_key;
        my $label_sep = $path_node->label_sep;

        if (!$self->has_vertex($node)) {

            $self->add_vertex($node);
            $self->set_label($node, $label);
            $self->set_path_node($node, $path_node);
            $self->init_bag($node, $bag_key => $label) if $bag_key;

        } else {

            $self->append_to_label($node, "$label_sep$label")
                if $bag_key
                && $self->add_to_bag($node, $bag_key, $label);
        }

        $self->add_edge($prev_path_node, $node) if
            $prev_path_node
            && !$self->has_edge($prev_path_node, $node);

        $prev_path_node = $node;
    }
}

method set_path_node(Str $node, Node $path_node)
    { $self->set_vertex_attribute($node, path_node => $path_node) }

method get_path_node(Str $node)
    { $self->get_vertex_attribute($node, 'path_node') }

method init_keys (Str $node, Str $key)
    { $self->init_bag($node, vimperKeys => $key) }

method init_commands (Str $node, Str $command_str)
    { $self->init_bag($node, vimperCommands => $command_str) }

method init_bag (Str $node, Str $name, Str $key)
    { $self->set_vertex_attribute($node, $name, {$key => 1}) }

method add_to_bag(Str $node, Str $name, Str $key) {
    my $existing= $self->get_vertex_attribute($node, $name);
    if (!exists $existing->{$key}) {
        $existing->{$key} = 1;
        return 1;
    }
    return 0;
}

sub escape {
    my $s = shift;
    $s =~ s/"/\\"/g;
    return $s;
}

1;

