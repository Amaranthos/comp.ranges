import std.algorithm;
import std.datetime;
import std.format;
import std.stdio;
import std.range;
import std.conv;

enum COLS_PER_DAY = 3;
enum COLS_PER_WEEK = 7 * COLS_PER_DAY;

void main()
{
	formatYear(2022, 3).writeln;
}

auto formatYear(int year, int monthsPerRow)
{
	enum colSpacing = 1;

	return year
		.datesInYear
		.byMonth
		.chunks(monthsPerRow)
		.map!(r =>
				r.formatMonths
				.array
				.pasteBlocks(colSpacing)
				.join("\n")
		)
		.join("\n\n");
}

auto datesInYear(int year) pure
{
	return Date(year, 1, 1)
		.recurrence!((a, n) => a[n - 1] + 1.days)
		.until!(a => a.year > year);
}

template isDateRange(R)
{
	enum isDateRange = isInputRange!R && is(ElementType!R : Date);
}

auto byMonth(InputRange)(InputRange dates) pure nothrow
if (isDateRange!InputRange)
{
	return dates.chunkBy!((a, b) => a.month == b.month);
}

unittest
{
	auto months = datesInYear(2020).byMonth();
	int month = 1;
	do
	{
		assert(!months.empty);
		assert(months.front.front == Date(2020, month, 1));
		months.popFront();
	}
	while (++month <= 12);

	assert(months.empty);
}

auto formatMonths(Range)(Range months) pure nothrow
if (isInputRange!Range && isDateRange!(ElementType!Range))
{
	return months.map!formatMonth;
}

auto formatMonth(Range)(Range monthDays) if (isDateRange!Range)
in (!monthDays.empty)
in (monthDays.front.day == 1)
{
	return chain([monthDays.front.month.monthTitle], monthDays.byWeek.formatWeek);
}

string monthTitle(Month month) pure nothrow
{
	static immutable string[] monthNames = [
		"January", "February", "March", "April", "May", "June",
		"July", "August", "September", "October", "November", "December"
	];
	static assert(monthNames.length == 12);

	auto name = monthNames[month - 1];
	assert(name.length < COLS_PER_WEEK);
	auto before = (COLS_PER_WEEK - name.length) / 2;
	auto after = COLS_PER_WEEK - name.length - before;

	return spaces(before) ~ name ~ spaces(after);
}

string spaces(size_t n) pure nothrow
{
	return std.array.replicate(" ", n);
}

auto byWeek(InputRange)(InputRange dates) pure nothrow
if (isDateRange!InputRange)
{
	static struct ByWeek
	{
		InputRange r;

		@property bool empty()
		{
			return r.empty;
		}

		@property auto front()
		{
			return until!((Date a) => a.dayOfWeek == DayOfWeek.sat)(r, OpenRight.no);
		}

		void popFront()
		in (!r.empty)
		{
			r.popFront();
			while (!r.empty && r.front.dayOfWeek != DayOfWeek.sun)
				r.popFront();
		}
	}

	return ByWeek(dates);
}

auto formatWeek(Range)(Range weeks) pure nothrow
if (isInputRange!Range && isDateRange!(ElementType!Range))
{
	static struct WeekStrings
	{
		Range r;

		@property bool empty()
		{
			return r.empty;
		}

		string front()
		in (!r.front.empty)
		out (s; s.length == COLS_PER_WEEK)
		{
			import std.array : appender;

			auto buf = appender!string();

			auto startDay = r.front.front.dayOfWeek;
			buf.put(spaces(COLS_PER_DAY * startDay));

			string[] days = r.front.map!((Date d) => d.day.format!" %2d").array;
			assert(days.length <= 7 - startDay);
			days.copy(buf);

			if (days.length < 7 - startDay)
			{
				buf.put(spaces(COLS_PER_DAY * (7 - startDay - days.length)));
			}

			return buf.data;
		}

		void popFront()
		{
			r.popFront();
		}
	}

	return WeekStrings(weeks);
}

unittest
{
	auto jan2020 = datesInYear(2020)
		.byMonth
		.front
		.byWeek
		.formatWeek
		.join("\n");

	assert(jan2020 ==
			`           1  2  3  4
  5  6  7  8  9 10 11
 12 13 14 15 16 17 18
 19 20 21 22 23 24 25
 26 27 28 29 30 31   `, jan2020.format!"\n%s");
}

auto pasteBlocks(Range)(Range ror, int sepWidth)
		if (isForwardRange!Range && is(
			ElementType!(ElementType!Range) : string))
{

	struct Lines
	{
		Range ror;
		string sep;
		size_t[] colWidths;
		bool _empty;

		this(Range _ror, string _sep)
		{
			ror = _ror;
			sep = _sep;
			_empty = ror.empty;

			foreach (r; ror.save)
			{
				colWidths ~= r.empty ? 0 : r.front.length;
			}
		}

		@property bool empty()
		{
			return _empty;
		}

		@property auto front()
		{
			return zip(ror.save, colWidths)
				.map!(a => a[0].empty ? spaces(a[1]) : a[0].front)
				.join(sep);
		}

		void popFront()
		in (!empty)
		{
			_empty = true;
			foreach (ref r; ror)
			{
				if (!r.empty)
				{
					r.popFront();
					if (!r.empty)
					{
						_empty = false;
					}
				}
			}
		}
	}

	static assert(isInputRange!Lines);

	return Lines(ror, sepWidth.spaces);
}
