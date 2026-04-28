package backend;

/**
 * LOCAL ENGINE — NotePool
 *
 *   notePool = new NotePool(64);
 *   var note = notePool.get(strumTime, noteData, oldNote);
 *   notePool.recycle(note);
 *   notePool.destroy();
 */

import objects.Note;

class NotePool
{
	var _free:Array<Note>   = [];
	var _active:Array<Note> = [];
	var _overflow:Int = 0;
	final _maxSize:Int;

	public var totalCreated(default, null):Int = 0;
	public var totalReused(default, null):Int = 0;

	public function new(initialSize:Int = 64, maxSize:Int = 256)
	{
		_maxSize = maxSize;

		for (i in 0...initialSize) {
			if (i >= _maxSize) break;

			var note:Note = new Note(0, 0, null, false, false, null);
			note.kill();
			_free.push(note);
			totalCreated++;
		}

		#if (debug || dev)
		trace('[NotePool] Init: prealloc=$initialSize, max=$maxSize');
		#end
	}

	public function get(strumTime:Float, noteData:Int, ?prevNote:Note, ?sustainNote:Bool = false, ?inEditor:Bool = false, ?createdFrom:Dynamic = null):Note
	{
		var note:Note;

		if (_free.length > 0)
		{
			note = _free.pop();
			note.revive();
			totalReused++;
		}
		else if (totalCreated < _maxSize)
		{
			note = new Note(strumTime, noteData, prevNote, sustainNote, inEditor, createdFrom);
			totalCreated++;
			_active.push(note);
			#if (debug || dev)
			trace('[NotePool] Pool expands : note created #$totalCreated');
			#end
			return note; // init
		}
		else
		{
			_overflow++;
			#if (debug || dev)
			trace('[NotePool] WARNING: pool max ($_maxSize), overflow #$_overflow');
			#end
			return new Note(strumTime, noteData, prevNote, sustainNote, inEditor, createdFrom);
		}

		note.reinit(strumTime, noteData, prevNote, sustainNote, inEditor, createdFrom);
		_active.push(note);
		return note;
	}

	public function recycle(note:Note)
	{
		if (note == null) return;
		if (!_active.remove(note)) return;

		note.kill();
		_free.push(note);
	}

	public function recycleAll():Void
	{
		while (_active.length > 0)
		{
			var note = _active.pop();
			if (note != null) {
				note.kill();
				_free.push(note);
			}
		}
	}

	public function getStats():String
	{
		var total = totalReused + totalCreated;
		var rate = total > 0
			? Math.round(totalReused / total * 100) : 0;
		return '[NotePool] Active: ${_active.length} | Free: ${_free.length} | '
			+ 'Created: $totalCreated | Reused: $totalReused | '
			+ 'Reused: $rate% | Overflow: $_overflow';
	}

	public function destroy():Void
	{
		for (note in _active) note.destroy();
		for (note in _free)   note.destroy();
		_active = [];
		_free   = [];

		totalCreated = 0;
		totalReused = 0;
		_overflow = 0;
	}
}
