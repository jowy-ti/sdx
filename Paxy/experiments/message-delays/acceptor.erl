-module(acceptor).
-export([start/2]).

%% Experimental copy of the acceptor used for the "message delays" section.
%% The only change with respect to paxy-source-files/acceptor.erl is that the
%% promise and vote messages can be delayed (configurable at run time through
%% the paxy_delays persistent term). A delay of 0 sends the message directly,
%% exactly like the original code.

start(Name, PanelId) ->
  spawn(fun() -> init(Name, PanelId) end).

init(Name, PanelId) ->
  Promised = order:null(),
  Voted = order:null(),
  Value = na,
  acceptor(Name, Promised, Voted, Value, PanelId).

acceptor(Name, Promised, Voted, Value, PanelId) ->
  receive
    {prepare, Proposer, Round} ->
      case order:gr(Round, Promised) of
        true ->
          send_delayed(Proposer, {promise, Round, Voted, Value}, promise_delay()),
          io:format("[Acceptor ~w] Phase 1: promised ~w voted ~w colour ~w~n",
                    [Name, Round, Voted, Value]),
          % Update gui
          Colour = case Value of na -> {0,0,0}; _ -> Value end,
          PanelId ! {updateAcc, "Voted: " ++ io_lib:format("~p", [Voted]),
                     "Promised: " ++ io_lib:format("~p", [Round]), Colour},
          acceptor(Name, Round, Voted, Value, PanelId);
        false ->
          Proposer ! {sorry, {prepare, Round}},
          acceptor(Name, Promised, Voted, Value, PanelId)
      end;
    {accept, Proposer, Round, Proposal} ->
      case order:goe(Round, Promised) of
        true ->
          send_delayed(Proposer, {vote, Round}, vote_delay()),
          case order:goe(Round, Voted) of
            true ->
              io:format("[Acceptor ~w] Phase 2: promised ~w voted ~w colour ~w~n",
                        [Name, Promised, Round, Proposal]),
              % Update gui
              PanelId ! {updateAcc, "Voted: " ++ io_lib:format("~p", [Round]),
                         "Promised: " ++ io_lib:format("~p", [Promised]), Proposal},
              acceptor(Name, Promised, Round, Proposal, PanelId);
            false ->
              acceptor(Name, Promised, Voted, Value, PanelId)
          end;
        false ->
          Proposer ! {sorry, {accept, Round}},
          acceptor(Name, Promised, Voted, Value, PanelId)
      end;
    stop ->
      PanelId ! stop,
      ok
  end.

%% ---------------------------------------------------------------------------
%% Delay injection
%% ---------------------------------------------------------------------------

promise_delay() ->
  case persistent_term:get(paxy_delays, {0, 0}) of
    {Promise, _Vote} -> Promise
  end.

vote_delay() ->
  case persistent_term:get(paxy_delays, {0, 0}) of
    {_Promise, Vote} -> Vote
  end.

send_delayed(Pid, Message, 0) ->
  Pid ! Message;
send_delayed(Pid, Message, Delay) ->
  timer:send_after(Delay, Pid, Message).
