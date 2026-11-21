-module(proposer).
-export([start/6]).

-define(timeout, 2000).
-define(backoff, 10).

start(Name, Proposal, Acceptors, Sleep, PanelId, Main) ->
  spawn(fun() -> init(Name, Proposal, Acceptors, Sleep, PanelId, Main) end).

init(Name, Proposal, Acceptors, Sleep, PanelId, Main) ->
  timer:sleep(Sleep),
  Begin = erlang:monotonic_time(),
  Round = order:first(Name),
  {Decision, LastRound} = round(Name, ?backoff, Round, Proposal, Acceptors, PanelId),
  End = erlang:monotonic_time(),
  Elapsed = erlang:convert_time_unit(End-Begin, native, millisecond),
  Main ! {done, Name, Decision, LastRound, Elapsed},
  PanelId ! stop.

round(Name, Backoff, Round, Proposal, Acceptors, PanelId) ->
  case ballot(Name, Round, Proposal, Acceptors, PanelId) of
    {ok, Value} ->
      {Value, Round};
    abort ->
      timer:sleep(rand:uniform(Backoff)),
      Next = order:inc(Round),
      round(Name, (2*Backoff), Next, Proposal, Acceptors, PanelId)
  end.

ballot(Name, Round, Proposal, Acceptors, PanelId) ->
  prepare(Round, Acceptors),
  Quorum = (length(Acceptors) div 2) + 1,
  MaxVoted = order:null(),
  case collect(Quorum, Round, MaxVoted, Proposal) of
    {accepted, Value} ->
      accept(Round, Value, Acceptors),
      case vote(Quorum, Round) of
        ok -> {ok, Value};
        abort -> abort
      end;
    abort ->
      abort
  end.

collect(0, _, _, Proposal) ->
  {accepted, Proposal};
collect(N, Round, MaxVoted, Proposal) ->
  receive
    {promise, Round, _, na} ->
      collect(N-1, Round, MaxVoted, Proposal);
    {promise, Round, Voted, Value} ->
      case order:gr(Voted, MaxVoted) of
        true -> collect(N-1, Round, Voted, Value);
        false -> collect(N-1, Round, MaxVoted, Proposal)
      end;
    {promise, _, _, _} ->
      collect(N, Round, MaxVoted, Proposal);
    {sorry, {prepare, Round}} ->
      collect(N, Round, MaxVoted, Proposal);
    {sorry, _} ->
      collect(N, Round, MaxVoted, Proposal)
  after ?timeout ->
    abort
  end.

vote(0, _) ->
  ok;
vote(N, Round) ->
  receive
    {vote, Round} -> vote(N-1, Round);
    {vote, _} -> vote(N, Round);
    {sorry, {accept, Round}} -> vote(N, Round);
    {sorry, _} -> vote(N, Round)
  after ?timeout ->
    abort
  end.

prepare(Round, Acceptors) ->
  lists:foreach(fun(A) -> A ! {prepare, self(), Round} end, Acceptors).

accept(Round, Proposal, Acceptors) ->
  lists:foreach(fun(A) -> A ! {accept, self(), Round, Proposal} end, Acceptors).
