import std.algorithm;
import std.datetime;
import std.format;
import std.stdio;
import std.range;

enum COLS_PER_DAY = 3;
enum COLS_PER_WEEK = 7 * COLS_PER_DAY;

void main()
{
	formatYear(2020, 3).writeln;
}

auto datesInYear(int year) pure
{
	return Date(year, 1, 1)
		.recurrence!((a, n) => a[n - 1] + 1.days)
		.until!(a => a.year > year);
}

auto byMonth(InputRange)(InputRange dates) pure nothrow
if (isDateRange!InputRange)
{
	return dates.chunkBy!(a => a.month());
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

template isDateRange(R)
{
	enum isDateRange = isInputRange!R && is(ElementType!R : Date);
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

auto formatMonths(Range)(Range months) pure nothrow



		if (isInputRange!Range && isInputRange!(ElementType!Range) && is(
			ElementType!(ElementType!Range) == Date))
{
	return months.map!formatMonth;
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

auto formatMonth(Range)(Range monthDays)
		if (isInputRange!Range && is(ElementType!Range == Date))
in (!monthDays.empty)
in (monthDays.front.day == 1)
{
	return chain([monthDays.front.month.monthTitle], monthDays.byWeek.formatWeek);
}

auto formatWeek(Range)(Range weeks) pure nothrow



		if (isInputRange!Range && isInputRange!(ElementType!Range) && is(
			ElementType!(ElementType!Range) == Date))
{
	struct WeekStrings
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

auto chunkBy(alias attrFun, Range)(Range r)
		if (isInputRange!Range && is(typeof(
			attrFun(ElementType!Range.init) == attrFun(ElementType!Range.init))))
{
	import std.functional : unaryFun;

	alias attr = unaryFun!attrFun;
	alias AttrType = typeof(attr(r.front));

	static struct Chunk
	{
		private Range r;
		private AttrType curAttr;

		@property bool empty()
		{
			return r.empty || !(curAttr == attr(r.front));
		}

		@property ElementType!Range front()
		{
			return r.front;
		}

		void popFront()
		in (!r.empty)
		{
			r.popFront();
		}
	}

	static struct ChunkBy
	{
		private Range r;
		private AttrType lastAttr;

		this(Range _r)
		{
			r = _r;
			if (!empty)
				lastAttr = attr(r.front);
		}

		@property bool empty()
		{
			return r.empty;
		}

		@property auto front()
		in (!r.empty)
		{
			return Chunk(r, lastAttr);
		}

		void popFront()
		in (!r.empty)
		{
			while (!r.empty && attr(r.front) == lastAttr)
				r.popFront();
			if (!r.empty)
				lastAttr = attr(r.front);
		}

		// static if (isForwardRange!Range)
		// {
		// 	@property ChunkBy save()
		// 	{
		// 		// ChunkBy copy;
		// 		// 		copy.r = r.save;
		// 		// 		copy.lastAttr = lastAttr;
		// 		return copy;
		// 	}
		// }
	}

	return ChunkBy(r);
}

unittest
{
	import std.algorithm : equal;

	auto range = [[1, 1], [1, 1], [1, 2], [2, 2], [2, 3], [2, 3], [3, 3]];

	auto byX = range.chunkBy!(a => a[0]);
	auto expectedX = [
		[[1, 1], [1, 1], [1, 2]], [[2, 2], [2, 3], [2, 3]], [[3, 3]]
	];

	foreach (e; byX)
	{
		assert(!expectedX.empty);
		assert(e.equal(expectedX.front));
		expectedX.popFront();
	}

	auto byY = range.chunkBy!(a => a[1]);
	auto expectedY = [
		[[1, 1], [1, 1]], [[1, 2], [2, 2]], [[2, 3], [2, 3], [3, 3]]
	];

	foreach (e; byY)
	{
		assert(!expectedY.empty);
		assert(e.equal(expectedY.front));
		expectedY.popFront();
	}
}

string spaces(size_t n) pure nothrow
{
	return std.array.replicate(" ", n);
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
