//
//  RichTextViewController.swift
//  NumberedLists
//
//  Created by Rhett Rogers on 3/7/16.
//  Copyright © 2016 LyokoTech. All rights reserved.
//

import UIKit

public class RichTextViewController: UIViewController {

    public var textView = UITextView()
    var afterNumberCharacter = "."
    var spaceAfterNumberCharacter = "\u{00A0}"
    var numberedListTrailer = ""
    var previousSelection = NSRange()
    
    override public init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        numberedListTrailer = "\(afterNumberCharacter)\(spaceAfterNumberCharacter)"
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func traitCollectionDidChange(previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
    }
    

    /// Replaces text in a range with text in parameter
    ///
    /// - parameter range: The range at which to replace the string.
    /// - parameter withText: The text that will be inserted.
    /// - parameter inTextView: The textView in which changes will occur.
    private func replaceTextInRange(range: NSRange, withText replacementText: String, inTextView textView: UITextView) {
        let substringLength = (textView.text as NSString).substringWithRange(range).length
        let lengthDifference = substringLength - replacementText.length
        let previousRange = textView.selectedRange
        let attributes = textView.attributedText.attributesAtIndex(range.location, effectiveRange: nil)
        
        textView.textStorage.beginEditing()
        textView.textStorage.replaceCharactersInRange(range, withAttributedString: NSAttributedString(string: replacementText, attributes: attributes))
        textView.textStorage.endEditing()
        
        let offset = lengthDifference - (previousRange.location - textView.selectedRange.location)
        textView.selectedRange.location -= offset
        
        textViewDidChangeSelection(textView)
    }
    
    /// Removes text from a textView at a specified index
    ///
    /// - parameter range: The range of the text to remove.
    /// - parameter toTextView: The `UITextView` to remove the text from.
    private func removeTextFromRange(range: NSRange, fromTextView textView: UITextView) {
        let substringLength = (textView.text as NSString).substringWithRange(range).length

        textView.textStorage.beginEditing()
        textView.textStorage.replaceCharactersInRange(range, withAttributedString: NSAttributedString(string: ""))
        textView.textStorage.endEditing()
        
        if range.comesBeforeRange(textView.selectedRange) {
            textView.selectedRange.location -= substringLength
        } else if range.containedInRange(textView.selectedRange) {
            textView.selectedRange.length -= substringLength
        } else if range.containsBeginningOfRange(textView.selectedRange) {
            let inSelectionRemoved = textView.selectedRange.location - range.location
            let outSelectionRemoved = range.length - inSelectionRemoved
            textView.selectedRange.location -= outSelectionRemoved
            textView.selectedRange.length -= inSelectionRemoved
        } else if range.containsEndOfRange(textView.selectedRange) {
            textView.selectedRange.length -= textView.selectedRange.endLocation - range.location
        }
        
        textViewDidChangeSelection(textView)
    }


    /// Adds text to a textView at a specified index
    ///
    /// - parameter text: The text to add.
    /// - parameter toTextView: The `UITextView` to add the text to.
    /// - parameter atIndex: The index to insert the text at.
    private func addText(text: String, toTextView textView: UITextView, atIndex index: Int) {

        let attributes = index < (textView.text as NSString).length ? textView.attributedText.attributesAtIndex(index, effectiveRange: nil) : textView.typingAttributes
        textView.textStorage.beginEditing()
        textView.textStorage.insertAttributedString(NSAttributedString(string: text, attributes: attributes), atIndex: index)
        textView.textStorage.endEditing()
        
        if textView.selectedRange.location <= index && index < textView.selectedRange.endLocation && textView.selectedRange.length > 0 {
            textView.selectedRange.length += text.length
        } else if index <= textView.selectedRange.location {
            textView.selectedRange.location += text.length
        }
        
        textViewDidChangeSelection(textView)
    }

    /// Toggles a numbered list on the current line if there is a zero-length selection;
    /// else removes all numbered lists in selection if they exist
    /// or adds them to each line if there are no numbered lists in selection
    public func toggleNumberedList() {
        if textView.selectedRange.length == 0 {
            if selectionContainsNumberedList(textView.selectedRange) {
                if let newLineIndex = textView.text.previousIndexOfSubstring("\n", fromIndex: textView.selectedRange.location) {
                    let previousNumber = previousNumberOfNumberedList(textView.selectedRange)

                    let range = NSRange(location: newLineIndex+1, length: "\(previousNumber)\(numberedListTrailer)".length)
                    removeTextFromRange(range, fromTextView: textView)
                } else {
                    removeTextFromRange(NSRange(location: 0, length: numberedListTrailer.length+1), fromTextView: textView)
                }
            } else {
                if let newLineIndex = textView.text.previousIndexOfSubstring("\n", fromIndex: textView.selectedRange.location) {
                    let newNumber = (previousNumberOfNumberedList(textView.selectedRange) ?? 0) + 1
                    let insertString = "\(newNumber)\(numberedListTrailer)"
                    addText(insertString, toTextView: textView, atIndex: newLineIndex + 1)
                } else {
                    let insertString = "1\(numberedListTrailer)"
                    addText(insertString, toTextView: textView, atIndex: 0)
                }
            }
        } else {
            
            var numbersInSelection = false
            
            if selectionContainsNumberedList(NSRange(location: textView.selectedRange.location, length: 0)), let range = previousNumberedRangeFromIndex(textView.selectedRange.location, inString: textView.text) {
                numbersInSelection = true
                removeTextFromRange(range, fromTextView: textView)
            }

            if selectionContainsNumberedList(textView.selectedRange) {
                numbersInSelection = true
                var index = textView.selectedRange.location
                while true {
                    guard let newRange = nextNumberedRangeFromIndex(index, inString: textView.text)
                        where newRange.location < textView.selectedRange.endLocation &&
                            newRange.endLocation < textView.text.length &&
                            newRange.length > -1
                        else {
                            break
                    }
                    removeTextFromRange(newRange, fromTextView: textView)
                    index = newRange.location
                }
            }
            
            if !numbersInSelection {
                let previousNumber = previousNumberOfNumberedList(textView.selectedRange)
                var newNumber = previousNumber + 1
                
                let previousNumberedIndex = textView.text.previousIndexOfSubstring(numberedListTrailer, fromIndex: textView.selectedRange.location) ?? -2
                let previousNewLineIndex = textView.text.previousIndexOfSubstring("\n", fromIndex: textView.selectedRange.location) ?? -1
                
                if previousNumberedIndex < previousNewLineIndex {
                    addText("\(newNumber)\(numberedListTrailer)", toTextView: textView, atIndex: previousNewLineIndex + 1)
                    newNumber += 1
                }
                
                var index = textView.selectedRange.location
                
                while true {
                    guard let newLineIndex = textView.text.nextIndexOfSubstring("\n", fromIndex: index) where
                        newLineIndex < textView.selectedRange.endLocation else { break }
                    addText("\(newNumber)\(numberedListTrailer)", toTextView: textView, atIndex: newLineIndex + 1)
                    newNumber += 1
                    index = newLineIndex + 1
                }
                
            }
        }
    }
    
    
    /// Returns the range of the previous "numbered list" line, starting at the beginning of the line
    ///
    /// - parameter index: The index to begin searching from.  Search will go before the index
    /// - parameter inString: The string to search in
    ///
    /// - returns: An `NSRange` describing the location of the previous number i.e. `"1. "`
    private func previousNumberedRangeFromIndex(index: Int, inString string: String) -> NSRange? {
        guard let numberedTrailerIndex = string.previousIndexOfSubstring(numberedListTrailer, fromIndex: index) else { return nil }
        
        var newLineIndex = string.previousIndexOfSubstring("\n", fromIndex: numberedTrailerIndex) ?? -1
        if newLineIndex >= -1 {
            newLineIndex += 1
        }
        
        return NSRange(location: newLineIndex, length: (numberedTrailerIndex - newLineIndex) + numberedListTrailer.length)
    }
    
    /// Returns the range of the next "numbered list" line, starting at the beginning of the line
    /// 
    /// - parameter index: The index to begin searching from.  Search will go after the index
    /// - parameter inString: The string to search in
    ///
    /// - returns: An `NSRange` describing the location of the next number i.e. `"1. "`
    private func nextNumberedRangeFromIndex(index: Int, inString string: String) -> NSRange? {
        
        guard let numberedTrailerIndex = string.nextIndexOfSubstring(numberedListTrailer, fromIndex: index) else { return nil }
        
        var newLineIndex = string.previousIndexOfSubstring("\n", fromIndex: numberedTrailerIndex) ?? -1
        
        if newLineIndex >= -1 {
            newLineIndex += 1
        }

        return NSRange(location: newLineIndex, length: (numberedTrailerIndex - newLineIndex) + numberedListTrailer.length)
    }

    /// Checks a `NSRange` selection to see if it contains a numbered list.
    /// Returns true if selection contains at least 1 numbered list, false otherwise.
    /// 
    /// - parameter selection: An `NSRange` to check
    ///
    /// - returns: True if selection contains at least 1 numbered list, false otherwise
    public func selectionContainsNumberedList(var selection: NSRange) -> Bool {
        var containsNumberedList = false

        if selection.length == 0 {
            if let previousIndex = textView.text.previousIndexOfSubstring(numberedListTrailer, fromIndex: selection.location) {
                if let newLineIndex = textView.text.previousIndexOfSubstring("\n", fromIndex: selection.location) {
                    if let comparisonIndex = textView.text.nextIndexOfSubstring(numberedListTrailer, fromIndex: newLineIndex) where previousIndex == comparisonIndex {
                        containsNumberedList = true
                    }
                } else {
                    containsNumberedList = true
                }
            } else {
                containsNumberedList = false
            }
        } else {
            let previousNumberedListIndex = textView.text.previousIndexOfSubstring(numberedListTrailer, fromIndex: selection.location) ?? selection.location
            let previousNewLineIndex = textView.text.previousIndexOfSubstring("\n", fromIndex: selection.location) ?? 0
            
            if previousNewLineIndex < previousNumberedListIndex {
                selection.location = previousNumberedListIndex
                selection.length = selection.length < 2 && (selection.location + 2 < textView.text.length) ? 2 : selection.length
                
                
                let substring = (textView.text as NSString).substringWithRange(selection)
                
                if substring.containsString(numberedListTrailer) {
                    containsNumberedList = true
                }
            } else if (textView.text as NSString).substringWithRange(selection).containsString(numberedListTrailer) {
                containsNumberedList = true
            }
        }

        return containsNumberedList
    }

    /// Returns the number of the previous number starting from the location of the selection.
    ///
    /// - parameter selection: The selection to check from
    ///
    /// - returns: Previous number if it exists in the current line, `nil` otherwise
    private func previousNumberOfNumberedList(selection: NSRange) -> Int {
        guard let previousIndex = textView.text.previousIndexOfSubstring(numberedListTrailer, fromIndex: selection.location) else { return 0 }
        
        var newLineIndex = textView.text.previousIndexOfSubstring("\n", fromIndex: selection.location) ?? -1
        guard newLineIndex < previousIndex else { return 0 }
        
        newLineIndex += 1

        return Int((textView.text as NSString).substringWithRange(NSRange(location: newLineIndex, length: previousIndex - newLineIndex))) ?? 0
    }

    /// Appends a number to the text view if we are currently in a list.  Also deletes existing number if there is no text on the line.  This function should be called when the user inserts a new line (presses return)
    ///
    /// - parameter range: The location to insert the number
    ///
    /// - returns: `true` if a number was added, `false` otherwise
    private func addedListsIfActiveInRange(range: NSRange) -> Bool {
        guard selectionContainsNumberedList(range) else { return false }

        let previousNumber = previousNumberOfNumberedList(range) ?? 0
        let previousNumberString = "\(previousNumber)\(numberedListTrailer)"
        let previousRange = NSRange(location: range.location - previousNumberString.length, length: previousNumberString.length)
        var newNumber = previousNumber + 1
        let newNumberString = "\n\(newNumber)\(numberedListTrailer)"

        if textView.attributedText.attributedSubstringFromRange(previousRange).string == previousNumberString {
            removeTextFromRange(previousRange, fromTextView: textView)
        } else {
            addText(newNumberString, toTextView: textView, atIndex: range.location)

            // TODO: Complete iterating through the string incrementing the numbers
            var index = range.location + newNumberString.length

            while true {
                let stringToReplace = "\(newNumber)\(numberedListTrailer)"
                index = textView.text.nextIndexOfSubstring(stringToReplace, fromIndex: index) ?? -1
                guard index >= 0 else { break }
                
                newNumber += 1
                
                replaceTextInRange(NSRange(location: index, length: stringToReplace.length), withText: "\(newNumber)\(numberedListTrailer)", inTextView: textView)
                index += 1
            }
        }

        return true
    }

    /// Removes a number from a numbered list.  This function should be called when the user is backspacing on a number of a numbered list
    ///
    /// - parameter range: The range from which to remove the number
    ///
    /// - returns: true if a number was removed, false otherwise
    private func removedListsIfActiveInRange(range: NSRange) -> Bool {
        guard textView.selectedRange.location > 2 else { return false }

        var removed = false
        let previousNumber = previousNumberOfNumberedList(textView.selectedRange) ?? 0
        let previousNumberString = "\(previousNumber)\(numberedListTrailer)"
        let previousRange = NSRange(location: range.location - previousNumberString.length + 1, length: previousNumberString.length)

        let subString = (textView.text as NSString).substringWithRange(previousRange)

        if subString == previousNumberString {
            removeTextFromRange(previousRange, fromTextView: textView)
            removed = true
        }
        return removed
    }
    
    /// Moves the selection out of a number.  Call this when a selection changes
    private func moveSelectionIfInRangeOfList() {
        guard textView.text.length > 3 else { return }
        
        var range = NSRange(location: textView.selectedRange.location, length: textView.selectedRange.length)
        
        func stringAtRange(range: NSRange) -> String {
            return (textView.text as NSString).substringWithRange(range)
        }
        
        if range.length == 0 {
            if range.location <= textView.text.length - 1 && stringAtRange(NSRange(location: range.location, length: 1)) == spaceAfterNumberCharacter {
                if previousSelection.location < range.location {
                    range.location += 1
                } else {
                    range.location = textView.text.previousIndexOfSubstring("\n", fromIndex: range.location) ?? 0
                }
            } else if range.location <= textView.text.length - 2 && stringAtRange(NSRange(location: range.location, length: 2)) == numberedListTrailer {
                if previousSelection.location < range.location {
                    range.location += 2
                } else {
                    range.location = textView.text.previousIndexOfSubstring("\n", fromIndex: range.location) ?? 0
                }
            } else if range.location > 0 && range.location < textView.text.length - 1 && stringAtRange(NSRange(location: range.location - 1, length: 1)) == "\n",
                let nextTrailerIndex = textView.text.nextIndexOfSubstring(numberedListTrailer, fromIndex: range.location),
                nextLineIndex = textView.text.nextIndexOfSubstring("\n", fromIndex: range.location)
                where nextTrailerIndex < nextLineIndex {
                    if previousSelection.location < range.location {
                        range.location = textView.text.nextIndexOfSubstring(numberedListTrailer, fromIndex: range.location) ?? textView.text.length
                    } else {
                        range.location -= 1
                    }
            }
        } else {
            if range.location <= textView.text.length - 1 && stringAtRange(NSRange(location: range.location, length: 1)) == spaceAfterNumberCharacter {
                if previousSelection.location < range.location {
                    range.location += 1
                    range.length -= 1
                } else {
                    let oldLocation = range.location
                    range.location = textView.text.previousIndexOfSubstring("\n", fromIndex: range.location) ?? 0
                    let lengthChange = oldLocation - range.location
                    range.length += lengthChange
                }
            } else if range.location <= textView.text.length - 2 && stringAtRange(NSRange(location: range.location, length: 2)) == numberedListTrailer {
                if previousSelection.location < range.location {
                    range.location += 2
                    range.length -= 2
                } else {
                    let oldLocation = range.location
                    range.location = textView.text.previousIndexOfSubstring("\n", fromIndex: range.location) ?? 0
                    let lengthChange = oldLocation - range.location
                    range.length += lengthChange
                }
            } else if range.location > 0 && range.location < textView.text.length - 1 && stringAtRange(NSRange(location: range.location - 1, length: 1)) == "\n",
                let nextTrailerIndex = textView.text.nextIndexOfSubstring(numberedListTrailer, fromIndex: range.location),
                nextLineIndex = textView.text.nextIndexOfSubstring("\n", fromIndex: range.location)
                where nextTrailerIndex < nextLineIndex {
                    if previousSelection.location < range.location {
                        let oldLocation = range.location
                        range.location = textView.text.nextIndexOfSubstring(numberedListTrailer, fromIndex: range.location) ?? textView.text.length - 2
                        range.location += 2
                        let lengthChange = range.location - oldLocation
                        range.length -= lengthChange
                    } else {
                        range.location -= 1
                        range.length += 1
                    }
            }
            
            if range.location + range.length <= textView.text.length - 1 && stringAtRange(NSRange(location: range.location + range.length, length: 1)) == spaceAfterNumberCharacter {
                if previousSelection.length < range.length {
                    range.length += 1
                } else {
                    var newLength = textView.text.previousIndexOfSubstring("\n", fromIndex: range.location + range.length) ?? range.length + 1
                    newLength -= newLength != range.length + 1 ? range.location : 0
                    range.length = newLength
                }
            } else if range.location + range.length <= textView.text.length - 2 && stringAtRange(NSRange(location: range.location + range.length, length: 2)) == numberedListTrailer {
                if previousSelection.length < range.length {
                    range.length += 2
                } else {
                    var newLength = textView.text.previousIndexOfSubstring("\n", fromIndex: range.location + range.length) ?? range.length + 2
                    newLength -= newLength != range.length + 2 ? range.location : 0
                    range.length = newLength
                }
            } else if range.location + range.length < textView.text.length - 1 && stringAtRange(NSRange(location: (range.location + range.length) - 1, length: 1)) == "\n",
                let nextTrailerIndex = textView.text.nextIndexOfSubstring(numberedListTrailer, fromIndex: range.location + range.length) {
                    let nextLineIndex = textView.text.nextIndexOfSubstring("\n", fromIndex: range.location + range.length) ?? textView.text.length - 1
                    if nextTrailerIndex < nextLineIndex {
                        if previousSelection.length < range.length {
                            var newLength = textView.text.nextIndexOfSubstring(numberedListTrailer, fromIndex: range.location + range.length) ?? range.length - 1
                            newLength = newLength != range.length - 1 ? (newLength - range.location) + 2 : 0
                            range.length = newLength
                        } else {
                            range.length -= 1
                        }
                    }
            }
        }
        
        if range.location != textView.selectedRange.location || range.length != textView.selectedRange.length {
            textView.selectedRange = range
        }
    }

}

extension RichTextViewController: UITextViewDelegate {
    
    public func textViewDidChangeSelection(textView: UITextView) {
        moveSelectionIfInRangeOfList()
        previousSelection = textView.selectedRange
    }

    public func textView(textView: UITextView, shouldChangeTextInRange range: NSRange, replacementText text: String) -> Bool {
        var changed = false

        switch text {
        case "\n":
            changed = addedListsIfActiveInRange(range)
        case "":
            changed = removedListsIfActiveInRange(range)
        default:
            break
        }

        return !changed
    }
}
