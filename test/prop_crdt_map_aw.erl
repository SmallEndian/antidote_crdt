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

-module(prop_crdt_map_aw).

-define(PROPER_NO_TRANS, true).
-include_lib("proper/include/proper.hrl").

%% API
-export([prop_map_spec/0]).


prop_map_spec() ->
 crdt_properties:crdt_satisfies_spec(antidote_crdt_map_aw, fun op/0, fun spec/1).


spec(Operations1) ->
  Operations = lists:flatmap(fun normalizeOp/1, Operations1),
  % the keys in the map are the ones that were updated and not deleted yet
  Keys = lists:usort([Key ||
    % has an update
    {AddClock, {update, {Key, _}}} <- Operations,
    % no remove after the update:
    [] == [Y || {RemoveClock, {remove, Y}} <- Operations, Key == Y, crdt_properties:clock_le(AddClock, RemoveClock)]
  ]),
  GroupedByKey = [{Key, nestedOps(Operations, Key)}  || Key <- Keys],
  NestedSpec = [{{Key,Type}, nestedSpec(Type, Ops)} || {{Key,Type}, Ops} <- GroupedByKey],
  %% TODO add reset operations
  lists:sort(NestedSpec).

nestedOps(Operations, {_,Type}=Key) ->
  Resets =
    case Type:is_operation(reset) of
      true ->
        [{Clock, reset} || {Clock, {remove, Key2}} <- Operations, Key == Key2];
      false -> []
    end,
  Resets ++ [{Clock, NestedOp} || {Clock, {update, {Key2, NestedOp}}} <- Operations, Key == Key2].

nestedSpec(antidote_crdt_map_aw, Ops) -> spec(Ops);
nestedSpec(antidote_crdt_orset, Ops) -> prop_crdt_orset:add_wins_set_spec(Ops);
nestedSpec(antidote_crdt_integer, Ops) -> prop_crdt_integer:spec(Ops).

% normalizes operations (update-lists into single update-operations)
normalizeOp({Clock, {update, List}}) when is_list(List) ->
  [{Clock, {update, X}} || X <- List];
normalizeOp({Clock, {remove, List}}) when is_list(List) ->
  [{Clock, {remove, X}} || X <- List];
normalizeOp(X) -> [X].


% generates a random operation
op() -> ?SIZED(Size, op(Size)).
op(Size) ->
  oneof([
    {update, nestedOp(Size)},
    {update, ?LET(L, list(nestedOp(Size div 2)), removeDuplicateKeys(L, []))},
    {remove, typed_key()},
    {remove, ?LET(L, list(typed_key()), lists:usort(L))}
  ]).

removeDuplicateKeys([], _) -> [];
removeDuplicateKeys([{Key,Op}|Rest], Keys) ->
  case lists:member(Key, Keys) of
    true -> removeDuplicateKeys(Rest, Keys);
    false -> [{Key, Op}|removeDuplicateKeys(Rest, [Key|Keys])]
  end.

nestedOp(Size) ->
  oneof(
    [
      {{key(), antidote_crdt_integer}, prop_crdt_integer:op()},
      {{key(), antidote_crdt_orset}, prop_crdt_orset:set_op()}
    ]
    ++
    if
      Size > 1 ->
        [{{key(), antidote_crdt_map_aw}, ?LAZY(op(Size div 2))}];
      true -> []
    end
    ).

typed_key() -> {key(), crdt_type()}.

crdt_type() ->
  oneof([antidote_crdt_integer, antidote_crdt_orset, antidote_crdt_map_aw]).

key() ->
  oneof([a,b,c,d]).





