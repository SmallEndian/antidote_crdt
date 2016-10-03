%% -------------------------------------------------------------------
%%
%% Copyright (c) 2014 SyncFree Consortium.  All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------

%% antidote_crdt_integer: A convergent, replicated, operation
%% based integer
%%
%%

-module(antidote_crdt_integer).

-behaviour(antidote_crdt).

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

-export([ new/0,
          value/1,
          downstream/2,
          update/2,
          equal/2,
          to_binary/1,
          from_binary/1,
          is_operation/1,
          require_state_downstream/1
        ]).

-type state() :: {[{term(), integer()}], integer()}.
-type update() ::
      {increment, integer()}
    | {set, integer()}.
-type effect() ::
      {increment, integer()}
    | {set, term(), [term()], integer()}.
-type value() :: integer().


-spec new() -> state().
new() ->
    {[{initial, 0}], 0}.

-spec value(state()) -> value().
value({Vals, Delta}) ->
    lists:max([X || {_,X} <- Vals]) + Delta.

-spec downstream(update(), state()) -> {ok, effect()}.
downstream({increment, N}, _State) ->
    {ok, {increment, N}};
downstream({set, N}, {Vals, Delta}) ->
    Overridden = [Tag || {Tag, _} <- Vals],
    {ok, {set, unique(), Overridden, N-Delta}}.

unique() ->
    crypto:strong_rand_bytes(20).

%% @doc Update a `pncounter()'. The first argument is either the atom
%% `increment' or `decrement' or the two tuples `{increment, pos_integer()}' or
%% `{decrement, pos_integer()}'. 
%% In the case of the former, the operation's amount
%% is `1'. Otherwise it is the value provided in the tuple's second element.
%% The 2nd argument is the `pncounter()' to update.
%%
%% returns the updated `pncounter()'
-spec update(effect(), state()) -> {ok, state()}.
update({set, Token, Overridden, N}, {Vals, Delta}) ->
    Surviving = [{T,V} || {T,V} <- Vals, not lists:member(T, Overridden)],
    {ok, {[{Token, N}|Surviving], Delta}};
update({increment, N}, {Vals, Delta}) ->
    {ok, {Vals, Delta + N}}.

%% @doc Compare if two `pncounter()' are equal. Only returns `true()' if both 
%% of their positive and negative entries are equal.
-spec equal(state(), state()) -> boolean().
equal(PNCnt1, PNCnt2) ->
    PNCnt1 =:= PNCnt2.

-spec to_binary(state()) -> binary().
to_binary(PNCounter) ->
    term_to_binary(PNCounter).

from_binary(Bin) ->
    %% @TODO something smarter
    {ok, binary_to_term(Bin)}.

%% @doc The following operation verifies
%%      that Operation is supported by this particular CRDT.
-spec is_operation(term()) -> boolean().
is_operation({increment, N}) when is_integer(N) -> true;
is_operation({set, N}) when is_integer(N) -> true;
is_operation(_) -> false.

%% @doc Returns true if ?MODULE:downstream/2 needs the state of crdt 
%%      to generate downstream effect    
require_state_downstream(_) ->
     false.



%% ===================================================================
%% EUnit tests
%% ===================================================================
-ifdef(TEST).

new_test() ->
    ?assertEqual(0, new()).

%% @doc test the correctness of `value()' function
value_test() ->
    PNCnt = 4,
    ?assertEqual(4, value(PNCnt)).

%% @doc test the correctness of increment without parameter.
update_increment_test() ->
    PNCnt0 = new(),
    {ok, PNCnt1} = update({increment, 1}, PNCnt0),
    {ok, PNCnt2} = update({increment, 2}, PNCnt1),
    {ok, PNCnt3} = update({increment, 1}, PNCnt2),
    ?assertEqual(4, value(PNCnt3)).

%% @doc test the correctness of increment by some numbers.
update_increment_by_test() ->
    PNCnt0 = new(),
    {ok, PNCnt1} = update({increment, 7}, PNCnt0),
    ?assertEqual(7, value(PNCnt1)).

%% @doc test the correctness of decrement.
update_decrement_test() ->
    PNCnt0 = new(),
    {ok, PNCnt1} = update({increment, 1}, PNCnt0),
    {ok, PNCnt2} = update({increment, 2}, PNCnt1),
    {ok, PNCnt3} = update({increment, 1}, PNCnt2),
    {ok, PNCnt4} = update({decrement, 1}, PNCnt3),
    ?assertEqual(3, value(PNCnt4)).

update_negative_params_test() ->
    PNCnt0 = new(),
    {ok, PNCnt1} = update({increment, -7}, PNCnt0),
    {ok, PNCnt2} = update({decrement, -5}, PNCnt1),
    ?assertEqual(-2, value(PNCnt2)).

equal_test() ->
    PNCnt1 = 4,
    PNCnt2 = 2,
    PNCnt3 = 2,
    ?assertNot(equal(PNCnt1, PNCnt2)),
    ?assert(equal(PNCnt2, PNCnt3)).

binary_test() ->
    PNCnt1 = 4,
    BinaryPNCnt1 = to_binary(PNCnt1),
    {ok, PNCnt2} = from_binary(BinaryPNCnt1),
    ?assert(equal(PNCnt1, PNCnt2)).

-endif.

    
