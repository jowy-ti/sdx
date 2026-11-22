-module(run).
-export([main/1]).

%% One trial of the node-count experiment.
%%   erl -noshell -pa ebin -run run main <acceptors> <proposers>
%% Output:
%%   RESULT,status,A,P,t_first,t_all,winner_round,max_round,messages,consensus,missing

-define(WATCHDOG, 300000).

main([AS, PS]) ->
  A = list_to_integer(AS),
  P = list_to_integer(PS),
  {Status, TFirst, TAll, Win, Max, Msgs, Consensus, Missing} = trial(A, P),
  io:format("RESULT,~s,~w,~w,~w,~w,~w,~w,~w,~s,~w~n",
            [Status, A, P, TFirst, TAll, Win, Max, Msgs, Consensus, Missing]),
  init:stop().

trial(A, P) ->
  ets:new(paxy_stats, [named_table, public, set, {write_concurrency, true}]),
  ets:insert(paxy_stats, {msgs, 0}),
  Sink = spawn(fun sink/0),
  AccNames = [list_to_atom("a" ++ integer_to_list(I)) || I <- lists:seq(1, A)],
  lists:foreach(fun(N) -> register(N, acceptor:start(N, Sink)) end, AccNames),
  Start = erlang:monotonic_time(millisecond),
  lists:foreach(
    fun(I) ->
        Name = list_to_atom(lists:flatten(io_lib:format("p~2..0B", [I]))),
        Colour = {(I*97) rem 256, (I*57) rem 256, (I*17) rem 256},
        proposer:start(Name, Colour, AccNames, 0, Sink, self())
    end,
    lists:seq(1, P)),
  collect(P, P, Start, []).

collect(0, P, Start, Results) ->
  summarise(P, Start, Results, done);
collect(N, P, Start, Results) ->
  receive
    {done, Name, Decision, Round, _Elapsed} ->
      Now = erlang:monotonic_time(millisecond),
      R = element(1, Round) + 1,
      collect(N-1, P, Start, [{Name, Decision, R, Now-Start} | Results])
  after ?WATCHDOG ->
      summarise(P, Start, Results, timeout)
  end.

summarise(P, _Start, Results, Status0) ->
  Sorted = lists:keysort(4, Results),
  Msgs = case ets:lookup(paxy_stats, msgs) of
           [{msgs, M}] -> M;
           [] -> 0
         end,
  Missing = P - length(Results),
  case Sorted of
    [] ->
      {timeout, -1, -1, -1, -1, Msgs, "n/a", Missing};
    [{_, _, Win, TFirst} | _] ->
      {_, _, _, TAll} = lists:last(Sorted),
      Max = lists:max([element(3, R) || R <- Sorted]),
      Decisions = [element(2, R) || R <- Sorted],
      Consensus = case length(lists:usort(Decisions)) of 1 -> "yes"; _ -> "no" end,
      Status = case Status0 of done -> "ok"; timeout -> "timeout" end,
      {Status, TFirst, TAll, Win, Max, Msgs, Consensus, Missing}
  end.

sink() ->
  receive _ -> sink() end.
