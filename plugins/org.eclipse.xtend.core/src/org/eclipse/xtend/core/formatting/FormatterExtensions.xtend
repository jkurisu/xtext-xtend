package org.eclipse.xtend.core.formatting

import com.google.inject.Inject
import org.eclipse.xtext.nodemodel.INode
import org.eclipse.xtext.xbase.lib.util.ToStringHelper

class FormatterExtensions {
	
	@Inject extension NodeModelAccess
	@Inject extension XtendFormatterConfigKeys
	
	def Iterable<FormattingData> newFormattingData(HiddenLeafs leafs, (FormattingDataInit)=>void init) {
		val it = new FormattingDataInit()
		init.apply(it)
		if(leafs.newLinesInComments == 0 && (newLines == 0 || space == ""))
			return newFormattingData(leafs, space, indentationChange)
		else
			return newFormattingData(leafs, newLine, newLine, indentationChange)
	}
	
	def Iterable<FormattingData> newFormattingData(HiddenLeafs leafs, String space, int indentationChange) {
		val result = <FormattingData>newArrayList
		for(leaf : leafs.leafs) 
			switch leaf {
				WhitespaceInfo: {
					result += new WhitespaceData(leaf.offset, leaf.length, indentationChange, space)
				}
				CommentInfo: {} 
			}
		result
	}
	
	def (IConfigurationValues<XtendFormatterConfigKeys>) => Iterable<FormattingData> newFormattingData(HiddenLeafs leafs, IConfigurationKey<?> key, int indentationChange) {
		switch key {
			BlankLineKey: [ IConfigurationValues<XtendFormatterConfigKeys> cfg |
				val blankline = cfg.get(key)
				val preserve = cfg.get(cfg.keys.preserveBlankLines)
				val min = blankline + 1
				val max = Math::max(preserve + 1, min)
				newFormattingData(leafs, min, max, indentationChange)
			]
			NewLineOrPreserveKey: [ IConfigurationValues<XtendFormatterConfigKeys> cfg |
				val newLine = cfg.get(key)
				val preserve = cfg.get(cfg.keys.preserveNewLines)
				newFormattingData(leafs, if(newLine) 1 else 0, if(preserve || newLine) 1 else 0, indentationChange)
			]
			NewLineKey: [ IConfigurationValues<XtendFormatterConfigKeys> cfg |
				val newLine = cfg.get(key)
				val minmax = if(newLine) 1 else 0
				newFormattingData(leafs, minmax, minmax, indentationChange)
			]
			WhitespaceKey: [ IConfigurationValues<XtendFormatterConfigKeys> cfg |
				val space = cfg.get(key)
				newFormattingData(leafs, if(space) " " else "", indentationChange)
			]
			default:
				throw new RuntimeException("can't handle configuration key")
		} 
	}
	
	def Iterable<FormattingData> newFormattingData(HiddenLeafs leafs, int minNewLines, int maxNewLines, int indentationChange) {
		val result = <FormattingData>newArrayList
		var applied = false
		for(leaf : leafs.leafs) 
			switch leaf {
				WhitespaceInfo: {
					val next = leaf.trailingComment
					if(next?.trailing) {
						val space = if(leaf.offset == 0) "" else " "
						result += new WhitespaceData(leaf.offset, leaf.length, indentationChange, space)
					} else if (!applied) {
						var newLines = Math::min(Math::max(leafs.newLines, minNewLines), maxNewLines)
						if(leaf.leadingComment?.endsWithNewLine)
							newLines = newLines - 1
						if(!leaf.leadingComment?.endsWithNewLine && newLines == 0)
							result += new WhitespaceData(leaf.offset, leaf.length, indentationChange, " ")
						else 
							result += new NewLineData(leaf.offset, leaf.length, indentationChange, newLines)
						applied = true
					} else {
						var newLines = 1
						if(leaf.leadingComment?.endsWithNewLine)
							newLines = newLines - 1
						result += new NewLineData(leaf.offset, leaf.length, indentationChange, newLines)
					}
				}
				CommentInfo: {} 
			}
		result
	}
	
	def String lookahead(FormattableDocument fmt, int offset, int length, (FormattableDocument)=>void format) {
		val lookahead = new FormattableDocument(fmt)
		format.apply(lookahead)
		lookahead.renderToString(offset, length)
	}
	
	def boolean fitsIntoLine(FormattableDocument fmt, int offset, int length, (FormattableDocument)=>void format) {
		val lookahead = fmt.lookahead(offset, length, format)
		if(lookahead.contains("\n")) {
			return false
		} else {
			val line = fmt.lineLengthBefore(offset) + lookahead.length
			return line <= fmt.cfg.get(maxLineWidth)
		}
	}
	
	def Iterable<FormattingData> append(INode node, (FormattingDataInit)=>void init) {
		if(node != null) {
			node.hiddenLeafsAfter.newFormattingData(init)
		}
	}
	
	def (IConfigurationValues<XtendFormatterConfigKeys>) => Iterable<FormattingData> append(INode node, IConfigurationKey<?> key) {
		if(node != null) {
			node.hiddenLeafsAfter.newFormattingData(key, 0)
		}
	}
	
	def Iterable<FormattingData> prepend(INode node, (FormattingDataInit)=>void init) {
		if(node != null) {
			node.hiddenLeafsBefore.newFormattingData(init)
		}
	}
	
	def Iterable<FormattingData> surround(INode node, (FormattingDataInit)=>void init) {
		val result = <FormattingData>newArrayList()
		if(node != null) {
			result += node.hiddenLeafsBefore.newFormattingData(init)
			result += node.hiddenLeafsAfter.newFormattingData(init)
		}
		result
	}
	
	def Iterable<FormattingData> surround(INode node, (FormattingDataInit)=>void before, (FormattingDataInit)=>void after) {
		val result = <FormattingData>newArrayList()
		if(node != null) {
			result += node.hiddenLeafsBefore.newFormattingData(before)
			result += node.hiddenLeafsAfter.newFormattingData(after)
		}
		result
	}
	
	def (IConfigurationValues<XtendFormatterConfigKeys>) => Iterable<FormattingData> prepend(INode node, IConfigurationKey<?> key) {
		if(node != null) {
			node.hiddenLeafsBefore.newFormattingData(key, 0)
		}
	}
}

class FormattingDataInit {
	public String space = null
	public int newLines = 0
	public int indentationChange = 0
	
	def newLine() {
		newLines = 1
	}
	
	def noSpace() {
		space = ""
	}
	
	def oneSpace() {
		space = " "
	}
	
	def increaseIndentation() {
		indentationChange = indentationChange + 1
	}
	
	def decreaseIndentation() {
		indentationChange = indentationChange - 1
	}
	
	override toString() {
		new ToStringHelper().toString(this)
	}
	
}

