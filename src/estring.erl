%% @author David Weldon
%% @copyright 2009 David Weldon
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%% http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%
%% @doc estring is a string manipulation library.

-module(estring).
-export([begins_with/2,
         contains/2,
         edit_distance/2,
         edit_distance/3,
         ends_with/2,
         format/2,
         is_integer/1,
         random/1,
         rot13/1,
         similarity/2,
         similarity/3,
         similarity/4,
         squeeze/1,
         squeeze/2,
         strip/1,
         strip_split/2]).
-define(CHARS, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789").
-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

%% @spec begins_with(string(), string()) -> bool()
%% @doc Returns `true' if `String' begins with `SubString',
%% and `false' otherwise.
%% ```
%% > estring:begins_with("fancy pants", "fancy").
%% true
%% '''
-spec begins_with(string(), string()) -> boolean().
begins_with(String, SubString) ->
    string:substr(String, 1, length(SubString)) =:= SubString.

%% @spec contains(string(), string()) -> bool()
%% @doc Returns `true' if `String' contains `SubString', and `false' otherwise.
%% ```
%% > estring:contains("los angeles", "angel").
%% true
%% '''
-spec contains(string(), string()) -> boolean().
contains(String, SubString) ->
    string:str(String, SubString) > 0.

%% @spec edit_distance(String1::string(), String2::string()) -> integer()
%% @doc Returns the damerau-levenshtein edit distance between `String1' and
%% `String2'. Note the comparison is case sensitive.
%% ```
%% > estring:edit_distance("theater", "theatre").
%% 1
%% '''
-spec edit_distance(string(), string()) -> integer().
edit_distance(Source, Source) -> 0;
edit_distance(Source, []) -> length(Source);
edit_distance([], Source) -> length(Source);
edit_distance(Source, Target) ->
    D1 = lists:seq(0, length(Target)),
    outer_loop([[]|Source], [[]|Target], {D1, D1}, 1).

outer_loop([S1|[S0|S]], T, {D2, D1}, I) ->
    D0 = inner_loop(T, [S1, S0], {[[]|D2], D1, [I]}),
    outer_loop([S0|S], T, {D1, D0}, I + 1);
outer_loop([_S|[]], _, {_D1, D0}, _) ->
    lists:last(D0).

inner_loop([_T|[]], _, {_D2, _D1, D0}) ->
    lists:reverse(D0);
inner_loop([T1|[T0|T]], [S1, S0], {D2, D1, D0}) ->
    [S1T1|[S1T0|_]] = D1,
    Cost = if T0 =:= S0 -> 0; true -> 1 end,
    NewDist1 = lists:min([hd(D0) + 1, S1T0 + 1, S1T1 + Cost]),
    NewDist2 =
        if T1 =/= [] andalso S1 =/= [] andalso T1 =:= S0 andalso T0 =:= S1 ->
                lists:min([NewDist1, hd(D2) + Cost]);
           true -> NewDist1
        end,
    inner_loop([T0|T], [S1, S0], {tl(D2), tl(D1), [NewDist2|D0]}).

%% @spec edit_distance(string(), string(), IgnoreCase::bool()) -> integer()
%% @doc Returns the damerau-levenshtein edit distance between `String1' and
%% `String2'. The comparison is case insensitive if `IgnoreCase' is `true'.
%% ```
%% > estring:edit_distance("receive", "RECIEVE", true).
%% 1
%% > estring:edit_distance("Cats", "cast", false).
%% 2
%% '''
-spec edit_distance(string(), string(), boolean()) -> integer().
edit_distance(String1, String2, true) ->
    S1 = string:to_lower(String1),
    S2 = string:to_lower(String2),
    edit_distance(S1, S2);
edit_distance(String1, String2, false) ->
    edit_distance(String1, String2).

%% @spec edit_distance_estimate(list(), list()) -> float()
%% @doc Establishes a very conservate lower bound for edit distance.
%% This is useful only for early exit evaluations.
-spec edit_distance_estimate(list(), list()) -> float().
edit_distance_estimate(L, L) -> 0.0;
edit_distance_estimate(L1, L2) ->
    %% Divide the estimate by 2 because replacements will be double counted.
    %% The downside of this is that inserts or deletes are undercounted.
    edit_distance_estimate(lists:sort(L1), lists:sort(L2), 0.0) / 2.

edit_distance_estimate([], L, D) ->
    D + length(L);
edit_distance_estimate(L, [], D) ->
    D + length(L);
edit_distance_estimate([H1|L1], [H2|L2], D) ->
    if
        H1 =:= H2 ->
            edit_distance_estimate(L1, L2, D);
        H1 < H2 ->
            edit_distance_estimate(L1, [H2|L2], D+1);
        H1 > H2 ->
            edit_distance_estimate([H1|L1], L2, D+1)
    end.

%% @spec ends_with(string(), string()) -> bool()
%% @doc Returns `true' if `String' ends with `SubString', and `false' otherwise.
%% ```
%% > estring:ends_with("fancy pants", "pants").
%% true
%% '''
-spec ends_with(string(), string()) -> boolean().
ends_with(String, SubString) ->
    begins_with(lists:reverse(String), lists:reverse(SubString)).

%% @spec format(string(), list()) -> string()
%% @doc Shortcut for `lists:flatten(io_lib:format(Format, Data))'.
%% ```
%% > estring:format("~w bottles of ~s on the wall", [99, "beer"]).
%% "99 bottles of beer on the wall"
%% '''
-spec format(string(), list()) -> string().
format(Format, Data) ->
    lists:flatten(io_lib:format(Format, Data)).

%% @spec is_integer(string()) -> bool()
%% @doc Returns `true' if `String' is a string representation of an integer,
%% and `false' otherwise.
%% ```
%% > estring:is_integer("35").
%% true
%% > estring:is_integer("35.4").
%% false
%% '''
-spec is_integer(string()) -> boolean().
is_integer([]) ->
    false;
is_integer(String) ->
    lists:all(fun(C) -> C >= 48 andalso C =< 57 end, String).

%% @spec random(integer()) -> string()
%% @doc Returns a random alphanumeric string of length `N'.
%% ```
%% > estring:random(32).
%% "LzahJub1KOMS0U66mdXHtHyMMXIdxv1t"
%% '''
-spec random(N::integer()) -> string().
random(N) when N > 0->
    random:seed(now()),
    [random_character() || _ <- lists:seq(1, N)].

random_character() ->
    lists:nth(random:uniform(62), ?CHARS).

%% @spec rot13(string()) -> string()
%% @doc Applies the rot13 substitution cipher to `String'.
%% ```
%% > estring:rot13("The Quick Brown Fox Jumps Over The Lazy Dog.").
%% "Gur Dhvpx Oebja Sbk Whzcf Bire Gur Ynml Qbt."
%% '''
-spec rot13(string()) -> string().
rot13(String) ->
    [r13(C) || C <- String].

r13(C) when (C >= $A andalso C =< $M) -> C + 13;
r13(C) when (C >= $a andalso C =< $m) -> C + 13;
r13(C) when (C >= $N andalso C =< $Z) -> C - 13;
r13(C) when (C >= $n andalso C =< $z) -> C - 13;
r13(C) -> C.

%% @spec similarity(string(), string()) -> float()
%% @doc Returns a score between 0 and 1, representing how similar `Source' is to
%% `Target' based on the edit distance and normalized by the length of `Target'.
%% Note the order of `Source' and `Target' matters, and the comparison is case
%% sensitive.
%% ```
%% > estring:similarity("yahoo", "boohoo").
%% 0.5
%% > estring:similarity("boohoo", "yahoo").
%% 0.4
%% '''
-spec similarity(string(), string()) -> float().
similarity(Source, Source) -> 1.0;
similarity(Source, Target) ->
    Score = (length(Target) - edit_distance(Source, Target)) / lists:max([length(Source),length(Target)]),
    case Score > 0 of
        true -> Score;
        false -> 0.0
    end.

%% @spec similarity(string(), string(), IgnoreCase::bool()) -> float()
%% @doc Returns a score between 0 and 1, representing how similar `Source' is to
%% `Target' based on the edit distance and normalized by the length of `Target'.
%% Note the order of `Source' and `Target' matters. The comparison is case
%% insensitive if `IgnoreCase' is `true'.
%% ```
%% > estring:similarity("linux", "Linux", true).
%% 1.0
%% '''
-spec similarity(string(), string(), boolean()) -> float().
similarity(Source, Target, true) ->
    S = string:to_lower(Source),
    T = string:to_lower(Target),
    similarity(S, T);
similarity(Source, Target, false) ->
    similarity(Source, Target).

%% @spec similarity(string(), string(), IgnoreCase::bool(), float()) ->
%%       {ok, float()} | {error, limit_reached}
%% @doc Returns a score between 0 and 1, representing how similar `Source' is to
%% `Target' based on the edit distance and normalized by the length of `Target'.
%% Note the order of `Source' and `Target' matters. The comparison is case
%% insensitive if `IgnoreCase' is `true'. A simple heuristic is used
%% to estimate the upper bound for similarity between `Source' and `Target'.
%% If the estimate is less than `LowerLimit', then `{error, limit_reached}' is
%% returned immediately. otherwise `{ok, float()}' or `{error, limit_reached}'
%% is returned based on a call to {@link similarity/3. similarity/3}.
%% ```
%% > estring:similarity("linux", "microsoft", false, 0.5).
%% {error,limit_reached}
%% '''
-spec similarity(string(), string(), boolean(), float()) ->
      {ok, float()} | {error, limit_reached}.
similarity(Source, Target, CaseInsensitive, LowerLimit) ->
    {S, T} = case CaseInsensitive of
                 true -> {string:to_lower(Source), string:to_lower(Target)};
                 false -> {Source, Target}
             end,
    case similarity_estimate(S, T) >= LowerLimit of
        true ->
            Score = similarity(S, T),
            case Score >= LowerLimit of
                true -> {ok, Score};
                false ->  {error, limit_reached}
            end;
        false -> {error, limit_reached}
    end.

%% @spec similarity_estimate(string(), string()) -> float()
%% @doc Establishes a very conservate upper bound for string similarity.
-spec similarity_estimate(string(), string()) -> float().
similarity_estimate(S, S) -> 1.0;
similarity_estimate(S, T) ->
    DistanceEstimate = edit_distance_estimate(S, T),
    SimilarityEstimate = (length(T) - DistanceEstimate ) / length(T),
    case SimilarityEstimate > 0 of
        true -> SimilarityEstimate;
        false -> 0.0
    end.

%% @spec squeeze(string()) -> string()
%% @doc Shortcut for `estring:squeeze(String, " ")'.
%% ```
%% > estring:squeeze("i need   a  squeeze!").
%% "i need a squeeze!"
%% '''
-spec squeeze(string()) -> string().
squeeze(String) -> squeeze(String, " ").

%% @spec squeeze(string(), char()) -> string()
%% @doc Returns a string where runs of `Char' are replaced with a single `Char'.
%% ```
%% > estring:squeeze("the cow says moooo", $o).
%% "the cow says mo"
%% > estring:squeeze("the cow says moooo", "o").
%% "the cow says mo"
%% '''
-spec squeeze(string(), char()) -> string().
squeeze(String, Char) when erlang:is_integer(Char) ->
    squeeze(String, Char, [], []);
squeeze(String, Char) when is_list(Char) ->
    squeeze(String, hd(Char), [], []).

squeeze([], _, _, Result) ->
    lists:reverse(Result);
squeeze([H|T], H, H, Result) ->
    squeeze(T, H, H, Result);
squeeze([H|T], Char, _, Result) ->
    squeeze(T, Char, H, [H|Result]).

%% @spec strip(string()) -> string()
%% @doc Returns a string where leading and trailing whitespace (`" ",\n\t\f\r')
%% has been removed. Note that `string:strip/1' only removes spaces.
%% ```
%% > estring:strip("\t  clean me   \r\n").
%% "clean me"
%% '''
-spec strip(string()) -> string().
strip(String) ->
    strip(String, [], []).

strip([], _, Result) ->
    lists:reverse(Result);
strip([H|T], [], []) ->
    case whitespace(H) of
        true -> strip(T, [], []);
        false -> strip(T, [], [H])
    end;
strip([H|T], WhiteSpace, Result) ->
    case whitespace(H) of
        true -> strip(T, [H|WhiteSpace], Result);
        false -> strip(T, [], [H|WhiteSpace] ++ Result)
    end.

whitespace($\t) -> true;
whitespace($\n) -> true;
whitespace($\f) -> true;
whitespace($\r) -> true;
whitespace($\ ) -> true;
whitespace(_) -> false.

%% @spec strip_split(string(), string()) -> list()
%% @doc Shortcut for
%% `re:split(estring:strip(String), SeparatorString, [{return, list}])'. This is
%% intended for parsing input like csv files.
%% ```
%% > estring:strip_split("first>,<second>,<third\r\n", ">,<").
%% ["first","second","third"]
%% '''
-spec strip_split(string(), string()) -> list().
strip_split(String, SeparatorString) ->
    re:split(strip(String), SeparatorString, [{return, list}]).

-ifdef(TEST).

begins_with_test_() ->
    [?_assertEqual(true, begins_with("foobar", "foo")),
     ?_assertEqual(false, begins_with("foobar", "bar"))].

contains_test_() ->
    [?_assertEqual(true, contains("foobar", "foo")),
     ?_assertEqual(true, contains("foobar", "bar")),
     ?_assertEqual(true, contains("foobar", "oba")),
     ?_assertEqual(false, contains("foobar", "car"))].

edit_distance_test_() ->
    [?_assertEqual(0, edit_distance("computer", "computer")),
     %% deletion
     ?_assertEqual(1, edit_distance("computer", "compter")),
     %% substitution
     ?_assertEqual(1, edit_distance("computer", "camputer")),
     %% insertion
     ?_assertEqual(1, edit_distance("computer", "computter")),
     %% transposition
     ?_assertEqual(1, edit_distance("computer", "comupter")),
     %% deletion + substitution + insertion
     ?_assertEqual(3, edit_distance("computer", "camputte")),
     %% transposition + insertion + deletion
     ?_assertEqual(3, edit_distance("computer", "cmoputte")),
     %% transposition + insertion + deletion, with source and target swapped
     ?_assertEqual(3, edit_distance("cmoputte", "computer")),
     ?_assertEqual(3, edit_distance("cars", "BaTS", false)),
     ?_assertEqual(3, edit_distance("cars", "BaTS")),
     ?_assertEqual(2, edit_distance("cars", "BaTS", true))].

edit_distance_estimate_test_() ->
    [?_assertEqual(0.0, edit_distance_estimate("abc", "abc")),
     ?_assertEqual(0.0, edit_distance_estimate("", "")),
     ?_assertEqual(1.5, edit_distance_estimate("abc", "")),
     ?_assertEqual(1.5, edit_distance_estimate("", "abc")),
     ?_assertEqual(0.0, edit_distance_estimate("abc", "cba")),
     ?_assertEqual(1.0, edit_distance_estimate("abc", "xbc")),
     ?_assertEqual(0.5, edit_distance_estimate("abc", "abbc")),
     ?_assertEqual(1.5, edit_distance_estimate("abcd", "abbcx")),
     ?_assertEqual(2.0, edit_distance_estimate("abcd", "aabbccdd"))].

ends_with_test_() ->
    [?_assertEqual(false, ends_with("foobar", "foo")),
     ?_assertEqual(true, ends_with("foobar", "bar"))].

format_test_() ->
    [?_assertEqual("99 bottles of beer on the wall",
                   format("~w bottles of ~s on the wall", [99, "beer"])),
     ?_assertEqual("", format("",[]))].

is_integer_test_() ->
    [?_assertEqual(true, ?MODULE:is_integer("0123")),
     ?_assertEqual(true, ?MODULE:is_integer("456789")),
     ?_assertEqual(true, ?MODULE:is_integer("9")),
     ?_assertEqual(false, ?MODULE:is_integer("10.3")),
     ?_assertEqual(false, ?MODULE:is_integer("01 23")),
     ?_assertEqual(false, ?MODULE:is_integer("1x2")),
     ?_assertEqual(false, ?MODULE:is_integer("")),
     ?_assertEqual(false, ?MODULE:is_integer("abc"))].

random_test() ->
    ?assertEqual(100, length(random(100))).

rot13_test_() ->
    S1 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234",
    S2 = "NOPQRSTUVWXYZABCDEFGHIJKLMnopqrstuvwxyzabcdefghijklm1234",
    [?_assertEqual(S2, rot13(S1)),
     ?_assertEqual(S1, rot13(S2))].

similarity2_test_() ->
    [?_assertEqual(0.8, similarity("yaho", "yahoo")),
     ?_assertEqual(0.75, similarity("espn", "epsn")),
     ?_assertEqual(0.25, similarity("car", "BaTS")),
     ?_assertEqual(0.0, similarity("cars", "c")),
     ?_assertEqual(0.25, similarity("c", "cars")),
     ?_assertEqual(1.0, similarity("", ""))].

similarity3_test_() ->
    [?_assertEqual(0.25, similarity("car", "BaTS", false)),
     ?_assertEqual(0.5, similarity("cars", "BATS", true))].

similarity4_test_() ->
    [?_assertEqual({ok, 1.0}, similarity("yahoo", "yahoo", true, 0.8)),
     ?_assertEqual({ok, 0.8}, similarity("yahoo", "bahoo", true, 0.8)),
     ?_assertEqual({ok, 0.8}, similarity("yahoo", "Yahoo", false, 0.7)),
     ?_assertEqual({error, limit_reached},
                   similarity("yahoo", "Yahoo", false, 0.9)),
     ?_assertEqual({error, limit_reached},
                   similarity("yahoo", "bahoo", true, 0.9))].

similarity_estimate_test_() ->
    [?_assertEqual(1.0, similarity_estimate("", "")),
     ?_assertEqual(0.0, similarity_estimate("abc", "def")),
     ?_assertEqual(1.0, similarity_estimate("abc", "cba")),
     ?_assertEqual(0.8, similarity_estimate("abcde", "xbcde"))].

squeeze_test_() ->
    [?_assertEqual("i need a squeeze!", squeeze("i need   a  squeeze!")),
     ?_assertEqual("i need a squeeze!", squeeze("i need   a  squeeze!", " ")),
     ?_assertEqual("yelow moon", squeeze("yellow moon", "l")),
     ?_assertEqual("babon mon", squeeze("baboon moon", "o")),
     ?_assertEqual("babon mon", squeeze("baboon moon", $o)),
     ?_assertEqual("the cow says mo", squeeze("the cow says moooo", $o))].

strip_test_() ->
    [?_assertEqual("hello world", strip("  hello world ")),
     ?_assertEqual("hello world", strip(" \t hello world\f\r")),
     ?_assertEqual("hello world", strip("hello world")),
     ?_assertEqual("hello  \tworld", strip(" hello  \tworld ")),
     ?_assertEqual("hello world", strip("hello world\n\n \t")),
     ?_assertEqual("", strip(" ")),
     ?_assertEqual("", strip(""))].

strip_split_test_() ->
    [?_assertEqual(["ab", "cd", "ef"], strip_split(" ab<#>cd<#>ef \n", "<#>")),
     ?_assertEqual(["a", "b", [], "c" ], strip_split("\ta,b,,c\r\f", ","))].

-endif.
