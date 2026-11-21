-module(acceptor).
-export([start/2]).

%% Acceptor for the node-count experiment. Same protocol as the baseline;
%% every protocol message received or sent is counted in the public ETS
%% table `paxy_stats' (key `msgs').

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
      count(),
      case order:gr(Round, Promised) of
        true ->
          count(),
          Proposer ! {promise, Round, Voted, Value},
          Colour = case Value of na -> {0,0,0}; _ -> Value end,
          PanelId ! {updateAcc, "Voted: " ++ io_lib:format("~p", [Voted]),
                     "Promised: " ++ io_lib:format("~p", [Round]), Colour},
          acceptor(Name, Round, Voted, Value, PanelId);
        false ->
          count(),
          Proposer ! {sorry, {prepare, Round}},
          acceptor(Name, Promised, Voted, Value, PanelId)
      end;
    {accept, Proposer, Round, Proposal} ->
      count(),
      case order:goe(Round, Promised) of
        true ->
          count(),
          Proposer ! {vote, Round},
          case order:goe(Round, Voted) of
            true ->
              acceptor(Name, Promised, Round, Proposal, PanelId);
            false ->
              acceptor(Name, Promised, Voted, Value, PanelId)
          end;
        false ->
          count(),
          Proposer ! {sorry, {accept, Round}},
          acceptor(Name, Promised, Voted, Value, PanelId)
      end;
    stop ->
      PanelId ! stop,
      ok
  end.

count() ->
  catch ets:update_counter(paxy_stats, msgs, 1),
  ok.
