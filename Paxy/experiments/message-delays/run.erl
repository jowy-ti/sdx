-module(run).
-export([main/1]).

%% Headless driver for the "message delays" experiment.
%%
%% Usage (from the shell script):
%%   erl -noshell -pa ebin -run run main PromiseDelay VoteDelay Timeout
%%
%% One fresh Erlang VM is used per trial so that registered acceptor names,
%% timers and mailboxes from a previous trial cannot interfere.
%%
%% Output: one CSV line
%%   status,promise,vote,timeout,t_first,t_all,winner_round,max_round,consensus,missing

-define(ACCEPTORS, [homer, marge, bart, lisa, maggie]).
-define(PROPOSERS, [{fry, {255,0,0}}, {bender, {0,255,0}}, {leela, {0,0,255}}]).
-define(SLEEPS, [0, 100, 200]).
-define(WATCHDOG, 12000).

main([PromiseS, VoteS, TimeoutS]) ->
  Promise = list_to_integer(PromiseS),
  Vote = list_to_integer(VoteS),
  Timeout = list_to_integer(TimeoutS),
  persistent_term:put(paxy_delays, {Promise, Vote}),
  persistent_term:put(paxy_timeout, Timeout),
  {Status, TFirst, TAll, WinRound, MaxRound, Consensus, Missing} =
    trial(Timeout),
  io:format("RESULT,~s,~w,~w,~w,~w,~w,~w,~w,~s,~w~n",
            [Status, Promise, Vote, Timeout, TFirst, TAll,
             WinRound, MaxRound, Consensus, Missing]),
  init:stop().

trial(_Timeout) ->
  Sink = spawn(fun sink/0),
  lists:foreach(fun(Name) -> register(Name, acceptor:start(Name, Sink)) end,
                ?ACCEPTORS),
  Start = erlang:monotonic_time(millisecond),
  lists:foreach(
    fun({{Name, Colour}, Sleep}) ->
        proposer:start(Name, Colour, ?ACCEPTORS, Sleep, Sink, self())
    end,
    lists:zip(?PROPOSERS, ?SLEEPS)),
  collect(length(?PROPOSERS), Start, []).

collect(0, Start, Results) ->
  summarise(Start, Results, done);
collect(N, Start, Results) ->
  receive
    {done, Name, Decision, Round, Elapsed} ->
      Now = erlang:monotonic_time(millisecond),
      collect(N-1, Start,
              [{Name, Decision, Round, Elapsed, Now-Start} | Results])
  after ?WATCHDOG ->
      summarise(Start, Results, timeout)
  end.

summarise(Start, Results, Status0) ->
  Count = length(Results),
  Missing = length(?PROPOSERS) - Count,
  %% Results are in reverse arrival order; sort by arrival time.
  Sorted = lists:keysort(5, Results),
  case Sorted of
    [] ->
      {timeout, -1, -1, -1, -1, "n/a", Missing};
    [{_, _, _, _, TFirst} | _] ->
      {_, _, _, _, TAll} = lists:last(Sorted),
      WinRound = element(3, hd(Sorted)),
      MaxRound = lists:max([element(3, R) || R <- Sorted]),
      Decisions = [element(2, R) || R <- Sorted],
      Consensus =
        case length(lists:usort(Decisions)) of
          1 -> "yes";
          _ -> "no"
        end,
      Status =
        case Status0 of
          done -> "ok";
          timeout -> "timeout"
        end,
      {Status, TFirst, TAll, WinRound, MaxRound, Consensus, Missing}
  end.

sink() ->
  receive
    _ -> sink()
  end.
