defmodule GlobalApi.UUID do
  use Bitwise, only_operators: true

  alias GlobalApi.Utils

  @typedoc """
  A hex-encoded UUID string.
  """
  @type t :: <<_::288>>

  @typedoc """
  A hex-encoded UUID string without dashes.
  """
  @type t_no_dash :: <<_::288>>

  @type raw :: <<_::128>>

  @doc """
  Casts to UUID.
  """
  @spec cast(t | t_no_dash | raw | any) :: {:ok, t} | :error
  def cast(<<
    a1, a2, a3, a4, a5, a6, a7, a8, ?-,
    b1, b2, b3, b4, ?-,
    c1, c2, c3, c4, ?-,
    d1, d2, d3, d4, ?-,
    e1, e2, e3, e4, e5, e6, e7, e8, e9, e10, e11, e12
  >>) do
    << c(a1), c(a2), c(a3), c(a4), c(a5), c(a6), c(a7), c(a8), ?-,
      c(b1), c(b2), c(b3), c(b4), ?-,
      c(c1), c(c2), c(c3), c(c4), ?-,
      c(d1), c(d2), c(d3), c(d4), ?-,
      c(e1), c(e2), c(e3), c(e4), c(e5), c(e6), c(e7), c(e8), c(e9), c(e10), c(e11), c(e12) >>
  catch
    :error -> :error
  else
    casted -> casted
  end

  def cast(<<
    a1, a2, a3, a4, a5, a6, a7, a8,
    b1, b2, b3, b4,
    c1, c2, c3, c4,
    d1, d2, d3, d4,
    e1, e2, e3, e4, e5, e6, e7, e8, e9, e10, e11, e12
  >>) do
    << c(a1), c(a2), c(a3), c(a4), c(a5), c(a6), c(a7), c(a8), ?-,
      c(b1), c(b2), c(b3), c(b4), ?-,
      c(c1), c(c2), c(c3), c(c4), ?-,
      c(d1), c(d2), c(d3), c(d4), ?-,
      c(e1), c(e2), c(e3), c(e4), c(e5), c(e6), c(e7), c(e8), c(e9), c(e10), c(e11), c(e12) >>
  catch
    :error -> :error
  else
    casted -> casted
  end

  def cast(<< _::128 >> = binary), do: encode(binary)
  def cast(_), do: :error

  def cast!(data) do
    result = cast(data)
    if result == :error do
      raise ArgumentError, "data should be a valid uuid"
    end
    result
  end

  @compile {:inline, c: 1}

  defp c(?0), do: ?0
  defp c(?1), do: ?1
  defp c(?2), do: ?2
  defp c(?3), do: ?3
  defp c(?4), do: ?4
  defp c(?5), do: ?5
  defp c(?6), do: ?6
  defp c(?7), do: ?7
  defp c(?8), do: ?8
  defp c(?9), do: ?9
  defp c(?A), do: ?a
  defp c(?B), do: ?b
  defp c(?C), do: ?c
  defp c(?D), do: ?d
  defp c(?E), do: ?e
  defp c(?F), do: ?f
  defp c(?a), do: ?a
  defp c(?b), do: ?b
  defp c(?c), do: ?c
  defp c(?d), do: ?d
  defp c(?e), do: ?e
  defp c(?f), do: ?f
  defp c(_),  do: throw(:error)

  defp encode(<<
    a1::4, a2::4, a3::4, a4::4, a5::4, a6::4, a7::4, a8::4,
    b1::4, b2::4, b3::4, b4::4,
    c1::4, c2::4, c3::4, c4::4,
    d1::4, d2::4, d3::4, d4::4,
    e1::4, e2::4, e3::4, e4::4, e5::4, e6::4, e7::4, e8::4, e9::4, e10::4, e11::4, e12::4
  >>) do
    << e(a1), e(a2), e(a3), e(a4), e(a5), e(a6), e(a7), e(a8), ?-,
      e(b1), e(b2), e(b3), e(b4), ?-,
      e(c1), e(c2), e(c3), e(c4), ?-,
      e(d1), e(d2), e(d3), e(d4), ?-,
      e(e1), e(e2), e(e3), e(e4), e(e5), e(e6), e(e7), e(e8), e(e9), e(e10), e(e11), e(e12) >>
  catch
    :error -> :error
  else
    encoded -> {:ok, encoded}
  end

  @compile {:inline, e: 1}

  defp e(0),  do: ?0
  defp e(1),  do: ?1
  defp e(2),  do: ?2
  defp e(3),  do: ?3
  defp e(4),  do: ?4
  defp e(5),  do: ?5
  defp e(6),  do: ?6
  defp e(7),  do: ?7
  defp e(8),  do: ?8
  defp e(9),  do: ?9
  defp e(10), do: ?a
  defp e(11), do: ?b
  defp e(12), do: ?c
  defp e(13), do: ?d
  defp e(14), do: ?e
  defp e(15), do: ?f

  @doc """
  This method doesn't verify the UUID, since it has been checked before we do this
  """
  def to_small(uuid) do
    <<s1::binary-8, _::binary-1, s2::binary-4, _::binary-1, s3::binary-4, _::binary-1, s4::binary-4, _::binary-1, s5::binary-12>> = uuid
    s1 <> s2 <> s3 <> s4 <> s5
  end

  def int_to_hex(int) do
    int_to_hex("", int, int, 0)
  end
  defp int_to_hex(result, number, rem, count) when rem > 0 do
    byte = number >>> div(count, 2) * 8
    byte = if rem(count, 2) == 1 do byte >>> 4 else byte end
    int_to_hex(<<e(byte &&& 0xF)>> <> result, number, byte &&& ~~~0xF, count + 1)
  end
  defp int_to_hex(result, _number, _rem, _count), do: result

  @doc """
  Convert a XUID to an encoded Floodgate UUID
  """
  def from_xuid(xuid) when is_integer(xuid) do
    hex_xuid = int_to_hex(xuid)
    byte_size = byte_size(hex_xuid)
    if byte_size > 16 do
      :illegal_xuid
    else
      Utils.repeat_or_return(hex_xuid, 32, "0")
    end
  end
end
