# Wrote this to learn how to do queries. Repeatedly copy/pasted this code into iex
# When copy/pasting into iex, you have to type an open paren ( and then paste and then a close paren )
# so that iex doesn't try to evaluate expressions whenever there's a newline

require Ecto.Query

defmodule Foo do
  def query_rooms_public() do
    Ret.Hub
    |> filter_by_entry_mode("allow")
    |> filter_by_allow_promotion(true)
  end

  def query_rooms_created_by_account(%Ret.Account{} = account) do
    Ret.Hub
    |> filter_by_entry_mode("allow")
    |> Ecto.Query.where([hub], hub.created_by_account_id == ^account.account_id)
  end

  def query_rooms_created_by_account(_account) do
    Ret.Hub
    |> Ecto.Query.where([_], false)
  end

  def query_rooms_favorite(%Ret.Account{} = account) do
    Ret.Hub
    |> filter_by_entry_mode("allow")
    |> Ecto.Query.join(:inner, [h], f in Ret.AccountFavorite,
      on: f.hub_id == h.hub_id and f.account_id == ^account.account_id
    )
  end

  def query_rooms_favorite(_account) do
    Ret.Hub
    |> Ecto.Query.where([_], false)
  end

  def filter_by_allow_promotion(query, allow) do
    query
    |> Ecto.Query.where([_], ^[allow_promotion: allow])
  end

  def filter_by_entry_mode(query, entry_mode) do
    query
    |> Ecto.Query.where([_], ^[entry_mode: entry_mode])
  end

  def maybe_created_by_account(conditions, %Ret.Account{} = account) do
    Ecto.Query.dynamic([hub], hub.created_by_account_id == ^account.account_id or ^conditions)
  end

  def maybe_created_by_account(conditions, _) do
    conditions
  end
end

account_work = Ret.Account.account_for_email("")
account_personal = Ret.Account.account_for_email("")

public = Foo.query_rooms_public()
created_by_work = Foo.query_rooms_created_by_account(account_work)
favorites_work = Foo.query_rooms_favorite(account_work)
intersection_work = public |> Ecto.Query.intersect(^created_by_work)
union_work = public |> Ecto.Query.union(^created_by_work) |> Ecto.Query.union(^favorites_work)

created_by_personal = Foo.query_rooms_created_by_account(account_personal)
favorites_personal = Foo.query_rooms_favorite(account_personal)
intersection_personal = public |> Ecto.Query.intersect(^created_by_personal)
union_personal = public |> Ecto.Query.union(^created_by_personal) |> Ecto.Query.union(^favorites_personal)

queries = [
  {:public, public},
  {:created_by_work, created_by_work},
  {:favorites_work, favorites_work},
  {:union_work, union_work},
  {:intersection_work, intersection_work},
  {:created_by_personal, created_by_personal},
  {:favorites_personal, favorites_personal},
  {:union_personal, union_personal},
  {:intersection_personal, intersection_personal},
  {:intersection_created_by_personal_and_work, created_by_work |> Ecto.Query.intersect(^created_by_personal)},
  {:intersection_favorite_personal_and_work, favorites_work |> Ecto.Query.intersect(^favorites_personal)}
]

queries
|> Enum.map(fn {name, query} ->
  results = query |> Ret.Repo.all()
  num = results |> length
  sids = results |> Enum.map(fn res -> res.hub_sid end)
  {name, num, sids}
end)

#
# [
#  {:public, 2, ["z7LQiNi", "SVnhCWq"]},
#  {:created_by_work, 5, ["y9gFPwQ", "z7LQiNi", "YDttnrt", "ehxr8vL", "69RYWVs"]},
#  {:favorites_work, 2, ["y9gFPwQ", "CdfpRjA"]},
#  {:union_work, 7,
#   ["SVnhCWq", "CdfpRjA", "69RYWVs", "ehxr8vL", "z7LQiNi", "y9gFPwQ", "YDttnrt"]},
#  {:intersection_work, 1, ["z7LQiNi"]},
#  {:created_by_personal, 33,
#   ["vwEpnZD", "UzMXFcB", "T2dPBV9", "ZceH2fW", "F8booHV", "mtjDvcT", "qpNN3T5",
#    "ZYZ5PE7", "qLRoSm8", "fXZ75nM", "qXNvzqH", "gLkm3ci", "ejv5YPj", "Rd8s8jG",
#    "bLYUYMN", "ywUEvZv", "V56MWQC", "EAtxxgX", "ktqpzTy", "63Gf4dA", "o4hDvex",
#    "SVnhCWq", "dEGWZha", "fjoXfyX", "rgKHo3S", "uVNWpsg", "aTU7PW9", "N3ckcDM",
#    "3wdzynX", "5wQhhbG", "CdfpRjA", "RmNv2k2", "4jByd2w"]},
#  {:favorites_personal, 7,
#   ["fjoXfyX", "uVNWpsg", "N3ckcDM", "5wQhhbG", "CdfpRjA", "RmNv2k2", "4jByd2w"]},
#  {:union_personal, 34,
#   ["3wdzynX", "uVNWpsg", "qLRoSm8", "rgKHo3S", "qXNvzqH", "UzMXFcB", "V56MWQC",
#    "aTU7PW9", "ywUEvZv", "mtjDvcT", "o4hDvex", "gLkm3ci", "dEGWZha", "ZYZ5PE7",
#    "fjoXfyX", "F8booHV", "z7LQiNi", "5wQhhbG", "4jByd2w", "fXZ75nM", "vwEpnZD",
#    "SVnhCWq", "ZceH2fW", "T2dPBV9", "N3ckcDM", "EAtxxgX", "ejv5YPj", "bLYUYMN",
#    "RmNv2k2", "ktqpzTy", "qpNN3T5", "CdfpRjA", "63Gf4dA", "Rd8s8jG"]},
#  {:intersection_personal, 1, ["SVnhCWq"]},
#  {:intersection_created_by_personal_and_work, 0, []},
#  {:intersection_favorite_personal_and_work, 1, ["CdfpRjA"]}
# ]
#
