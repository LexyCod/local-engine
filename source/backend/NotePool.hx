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

	var _maxSize:Int;

	public var totalCreated:Int = 0;
	public var totalReused:Int  = 0;

	public function new(initialSize:Int = 64, maxSize:Int = 256)
	{
		_maxSize = maxSize;
		#if debug
		trace('[NotePool] Init, max=$maxSize');
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
			#if debug
			trace('[NotePool] Pool expands : note created #$totalCreated');
			#end
			return note; // init
		}
		else
		{
			_overflow++;
			#if debug
			trace('[NotePool] WARNING: pool max ($_maxSize), overflow #$_overflow');
			#end
			return new Note(strumTime, noteData, prevNote, sustainNote, inEditor, createdFrom);
		}

		note.reinit(strumTime, noteData, prevNote, sustainNote, inEditor, createdFrom);
		_active.push(note);
		return note;
	}

	public function recycle(note:Note):Void
	{
		if (note == null) return;

		var idx = _active.indexOf(note);
		if (idx == -1)
		{
			note.destroy();
			return;
		}

		_active.splice(idx, 1);
		note.kill();
		_free.push(note);
	}

	public function recycleAll():Void
	{
		while (_active.length > 0)
		{
			var note = _active.pop();
			note.kill();
			_free.push(note);
		}
	}

	public function getStats():String
	{
		var rate = totalReused + totalCreated > 0
			? Math.round(totalReused / (totalReused + totalCreated) * 100) : 0;
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
	}
}
