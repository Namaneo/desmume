/*
	Copyright (C) 2011 Roger Manuel
	Copyright (C) 2012-2023 DeSmuME team

	This file is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 2 of the License, or
	(at your option) any later version.

	This file is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with the this software.  If not, see <http://www.gnu.org/licenses/>.
*/

#import "cocoa_cheat.h"
#import "cocoa_globals.h"
#import "cocoa_util.h"

#include "../../cheatSystem.h"
#include "../../MMU.h"
#undef BOOL


size_t CheatConvertRawCodeToCleanCode(const char *inRawCodeString, const size_t requestedCodeCount, std::string &outCleanCodeString)
{
	size_t cleanCodeLength = 0;
	if ( (inRawCodeString == NULL) ||
		 (requestedCodeCount == 0) )
	{
		return cleanCodeLength;
	}
	
	char *cleanCodeWorkingBuffer = (char *)malloc((requestedCodeCount * 16) + 1);
	memset(cleanCodeWorkingBuffer, 0, (requestedCodeCount * 16) + 1);
	
	size_t rawCodeLength = strlen(inRawCodeString);
	// remove wrong chars
	for (size_t i = 0; (i < rawCodeLength) && (cleanCodeLength < (requestedCodeCount * 16)); i++)
	{
		char c = inRawCodeString[i];
		//apparently 100% of pokemon codes were typed with the letter O in place of zero in some places
		//so let's try to adjust for that here
		static const char *AR_Valid = "Oo0123456789ABCDEFabcdef";
		if (strchr(AR_Valid, c))
		{
			if ( (c == 'o') || (c == 'O') )
			{
				c = '0';
			}
			
			cleanCodeWorkingBuffer[cleanCodeLength++] = c;
		}
	}
	
	if ( (cleanCodeLength % 16) != 0)
	{
		// Code lines must always come in 8+8, where the first 8 characters
		// are used for the target address, and the second 8 characters are
		// used for the 32-bit value written to the target address. Therefore,
		// if the string length isn't divisible by 16, then it is considered
		// invalid.
		cleanCodeLength = 0;
		free(cleanCodeWorkingBuffer);
		return cleanCodeLength;
	}
	
	outCleanCodeString = cleanCodeWorkingBuffer;
	free(cleanCodeWorkingBuffer);
	
	return (cleanCodeLength / 16);
}

size_t CheatConvertCleanCodeToRawCode(const char *inCleanCodeString, std::string &outRawCodeString)
{
	if (inCleanCodeString == NULL)
	{
		return 0;
	}
	
	// Clean code strings are assumed to be already validated, so we're not
	// going to bother with any more validation here.
	
	const size_t cleanCodeLength = strlen(inCleanCodeString);
	const size_t codeCount = cleanCodeLength / 16;
	const size_t rawCodeLength = codeCount * (16 + 1 + 1);
	
	char *rawCodeWorkingBuffer = (char *)malloc(rawCodeLength);
	memset(rawCodeWorkingBuffer, 0, rawCodeLength);
	
	for (size_t i = 0; i < codeCount; i++)
	{
		const size_t c = i * 16;
		const size_t r = i * (16 + 1 + 1);
		
		rawCodeWorkingBuffer[r + 0] = inCleanCodeString[c + 0];
		rawCodeWorkingBuffer[r + 1] = inCleanCodeString[c + 1];
		rawCodeWorkingBuffer[r + 2] = inCleanCodeString[c + 2];
		rawCodeWorkingBuffer[r + 3] = inCleanCodeString[c + 3];
		rawCodeWorkingBuffer[r + 4] = inCleanCodeString[c + 4];
		rawCodeWorkingBuffer[r + 5] = inCleanCodeString[c + 5];
		rawCodeWorkingBuffer[r + 6] = inCleanCodeString[c + 6];
		rawCodeWorkingBuffer[r + 7] = inCleanCodeString[c + 7];
		rawCodeWorkingBuffer[r + 8] = ' ';
		rawCodeWorkingBuffer[r + 9] = inCleanCodeString[c + 8];
		rawCodeWorkingBuffer[r +10] = inCleanCodeString[c + 9];
		rawCodeWorkingBuffer[r +11] = inCleanCodeString[c +10];
		rawCodeWorkingBuffer[r +12] = inCleanCodeString[c +11];
		rawCodeWorkingBuffer[r +13] = inCleanCodeString[c +12];
		rawCodeWorkingBuffer[r +14] = inCleanCodeString[c +13];
		rawCodeWorkingBuffer[r +15] = inCleanCodeString[c +14];
		rawCodeWorkingBuffer[r +16] = inCleanCodeString[c +15];
		rawCodeWorkingBuffer[r +17] = '\n';
	}
	
	rawCodeWorkingBuffer[rawCodeLength - 1] = '\0';
	outRawCodeString = rawCodeWorkingBuffer;
	
	return codeCount;
}

bool IsCheatItemDuplicate(const ClientCheatItem *first, const ClientCheatItem *second)
{
	bool isDuplicate = false;
	
	if ( (first == NULL) || (second == NULL) )
	{
		return isDuplicate;
	}
	
	if (first == second)
	{
		isDuplicate = true;
		return isDuplicate;
	}
	
	const CheatType compareType = first->GetType();
	
	switch (compareType)
	{
		case CheatType_Internal:
		{
			if ( (first->GetAddress()     == second->GetAddress()) &&
				 (first->GetValueLength() == second->GetValueLength()) &&
				 (first->GetValue()       == second->GetValue()) )
			{
				isDuplicate = true;
			}
			break;
		}
			
		case CheatType_ActionReplay:
		{
			if ( (first->GetCodeCount()          == second->GetCodeCount()) &&
				 (first->GetCleanCodeCppString() == second->GetCleanCodeCppString()) )
			{
				isDuplicate = true;
			}
			break;
		}
			
		case CheatType_CodeBreaker:
		default:
			break;
	}
	
	return isDuplicate;
}

ClientCheatItem::ClientCheatItem()
{
	_cheatManager = NULL;
	
	_isEnabled = false;
	_willAddFromDB = false;
	
	_cheatType = CheatType_Internal;
	_descriptionString = "No description.";
	_freezeType = CheatFreezeType_Normal;
	_address = 0x02000000;
	strncpy(_addressString, "0x02000000", sizeof(_addressString));
	_valueLength = 1;
	_value = 0;
	
	_codeCount = 1;
	_rawCodeString = "02000000 00000000";
	_cleanCodeString = "0200000000000000";
}

ClientCheatItem::~ClientCheatItem()
{
	
}

void ClientCheatItem::Init(const CHEATS_LIST &inCheatItem)
{
	char workingCodeBuffer[32];
	
	this->_isEnabled = (inCheatItem.enabled) ? true : false;
	
	this->_cheatType = (CheatType)inCheatItem.type;
	this->_descriptionString = inCheatItem.description;
	
	this->_freezeType = (CheatFreezeType)inCheatItem.freezeType;
	this->_valueLength = inCheatItem.size + 1; // CHEATS_LIST.size value range is [1...4], but starts counting from 0.
	this->_address = inCheatItem.code[0][0];
	this->_addressString[0] = '0';
	this->_addressString[1] = 'x';
	snprintf(this->_addressString + 2, sizeof(this->_addressString) - 2, "%08X", this->_address);
	this->_value = inCheatItem.code[0][1];
	
	snprintf(workingCodeBuffer, 18, "%08X %08X", this->_address, this->_value);
	this->_rawCodeString = workingCodeBuffer;
	snprintf(workingCodeBuffer, 17, "%08X%08X", this->_address, this->_value);
	this->_cleanCodeString = workingCodeBuffer;
	
	if (this->_cheatType == CheatType_Internal)
	{
		this->_codeCount = 1;
	}
	else if (this->_cheatType == CheatType_ActionReplay)
	{
		this->_codeCount = inCheatItem.num;
		
		for (size_t i = 1; i < this->_codeCount; i++)
		{
			snprintf(workingCodeBuffer, 19, "\n%08X %08X", inCheatItem.code[i][0], inCheatItem.code[i][1]);
			this->_rawCodeString += workingCodeBuffer;
			snprintf(workingCodeBuffer, 17, "%08X%08X", inCheatItem.code[i][0], inCheatItem.code[i][1]);
			this->_cleanCodeString += workingCodeBuffer;
		}
	}
}

void ClientCheatItem::Init(const ClientCheatItem &inCheatItem)
{
	this->SetEnabled(inCheatItem.IsEnabled());
	this->SetDescription(inCheatItem.GetDescription());
	this->SetType(inCheatItem.GetType());
	this->SetFreezeType(inCheatItem.GetFreezeType());
	
	if (this->GetType() == CheatType_Internal)
	{
		this->SetValueLength(inCheatItem.GetValueLength());
		this->SetAddress(inCheatItem.GetAddress());
		this->SetValue(inCheatItem.GetValue());
	}
	else
	{
		this->SetRawCodeString(inCheatItem.GetRawCodeString(), false);
	}
}

void ClientCheatItem::SetCheatManager(ClientCheatManager *cheatManager)
{
	this->_cheatManager = cheatManager;
}

ClientCheatManager* ClientCheatItem::GetCheatManager() const
{
	return this->_cheatManager;
}

void ClientCheatItem::SetEnabled(bool theState)
{
	if ( (this->_isEnabled != theState) && (this->_cheatManager != NULL) )
	{
		this->_cheatManager->MasterNeedsUpdate();
	}
	
	this->_isEnabled = theState;
}

bool ClientCheatItem::IsEnabled() const
{
	return this->_isEnabled;
}

void ClientCheatItem::SetWillAddFromDB(bool theState)
{
	this->_willAddFromDB = theState;
}

bool ClientCheatItem::WillAddFromDB() const
{
	return this->_willAddFromDB;
}

CheatType ClientCheatItem::GetType() const
{
	return this->_cheatType;
}

void ClientCheatItem::SetType(CheatType requestedType)
{
	switch (requestedType)
	{
		case CheatType_Internal:
		case CheatType_ActionReplay:
		case CheatType_CodeBreaker:
			// Do nothing.
			break;
			
		default:
			// Bail if the cheat type is invalid.
			return;
	}
	
	if ( (this->_cheatType != requestedType) && (this->_cheatManager != NULL) && this->_isEnabled )
	{
		this->_cheatManager->MasterNeedsUpdate();
	}
	
	this->_cheatType = requestedType;
}

bool ClientCheatItem::IsSupportedType() const
{
	return (this->_cheatType != CheatType_CodeBreaker);
}

const char* ClientCheatItem::GetDescription() const
{
	return this->_descriptionString.c_str();
}

void ClientCheatItem::SetDescription(const char *descriptionString)
{
	if (descriptionString == NULL)
	{
		this->_descriptionString = "";
	}
	else
	{
		this->_descriptionString = descriptionString;
	}
}

CheatFreezeType ClientCheatItem::GetFreezeType() const
{
	return this->_freezeType;
}

void ClientCheatItem::SetFreezeType(CheatFreezeType theFreezeType)
{
	switch (theFreezeType)
	{
		case CheatFreezeType_Normal:
		case CheatFreezeType_CanDecrease:
		case CheatFreezeType_CanIncrease:
			// Do nothing.
			break;
			
		default:
			// Bail if the freeze type is invalid.
			return;
	}
	
	if ( (this->_freezeType != theFreezeType) && (this->_cheatManager != NULL) && this->_isEnabled )
	{
		this->_cheatManager->MasterNeedsUpdate();
	}
	
	this->_freezeType = theFreezeType;
}

uint32_t ClientCheatItem::GetAddress() const
{
	if (this->_cheatType != CheatType_Internal)
	{
		return 0;
	}
	
	return this->_address;
}

void ClientCheatItem::SetAddress(uint32_t theAddress)
{
	if ( (this->_address != theAddress) && (this->_cheatType == CheatType_Internal) && (this->_cheatManager != NULL) && this->_isEnabled )
	{
		this->_cheatManager->MasterNeedsUpdate();
	}
	
	this->_address = theAddress;
	
	this->_addressString[0] = '0';
	this->_addressString[1] = 'x';
	snprintf(this->_addressString + 2, 9, "%08X", theAddress);
	this->_addressString[10] = '\0';
	
	if (this->_cheatType == CheatType_Internal)
	{
		this->_ConvertInternalToActionReplay();
	}
}

const char* ClientCheatItem::GetAddressString() const
{
	return this->_addressString;
}

const char* ClientCheatItem::GetAddressSixDigitString() const
{
	return (this->_addressString + 4);
}

void ClientCheatItem::SetAddressSixDigitString(const char *sixDigitString)
{
	this->_addressString[0] = '0';
	this->_addressString[1] = 'x';
	this->_addressString[2] = '0';
	this->_addressString[3] = '2';
	
	if (sixDigitString == NULL)
	{
		this->_addressString[4] = '0';
		this->_addressString[5] = '0';
		this->_addressString[6] = '0';
		this->_addressString[7] = '0';
		this->_addressString[8] = '0';
		this->_addressString[9] = '0';
	}
	else
	{
		this->_addressString[4] = sixDigitString[0];
		this->_addressString[5] = sixDigitString[1];
		this->_addressString[6] = sixDigitString[2];
		this->_addressString[7] = sixDigitString[3];
		this->_addressString[8] = sixDigitString[4];
		this->_addressString[9] = sixDigitString[5];
	}
	
	this->_addressString[10] = '\0';
	
	u32 theAddress = 0;
	sscanf(this->_addressString + 2, "%x", &theAddress);
	
	if ( (this->_address != theAddress) && (this->_cheatType == CheatType_Internal) && (this->_cheatManager != NULL) && this->_isEnabled )
	{
		this->_cheatManager->MasterNeedsUpdate();
	}
	
	this->_address = theAddress;
	
	if (this->_cheatType == CheatType_Internal)
	{
		this->_ConvertInternalToActionReplay();
	}
}

uint32_t ClientCheatItem::GetValue() const
{
	return this->_value;
}

void ClientCheatItem::SetValue(uint32_t theValue)
{
	if ( (this->_value != theValue) && (this->_cheatType == CheatType_Internal) && (this->_cheatManager != NULL) && this->_isEnabled )
	{
		this->_cheatManager->MasterNeedsUpdate();
	}
	
	this->_value = theValue;
	
	if (this->_cheatType == CheatType_Internal)
	{
		this->_ConvertInternalToActionReplay();
	}
}

uint8_t ClientCheatItem::GetValueLength() const
{
	return this->_valueLength;
}

void ClientCheatItem::SetValueLength(uint8_t byteLength)
{
	if ( (this->_valueLength != byteLength) && (this->_cheatType == CheatType_Internal) && (this->_cheatManager != NULL) && this->_isEnabled )
	{
		this->_cheatManager->MasterNeedsUpdate();
	}
	
	this->_valueLength = byteLength;
	
	if (this->_cheatType == CheatType_Internal)
	{
		this->_ConvertInternalToActionReplay();
	}
}

void ClientCheatItem::SetRawCodeString(const char *rawString, const bool willSaveValidatedRawString)
{
	std::string newCleanCodeString;
	
	size_t cleanCodeCount = CheatConvertRawCodeToCleanCode(rawString, 1024, this->_cleanCodeString);
	if (cleanCodeCount == 0)
	{
		return;
	}
	
	this->_codeCount = (uint32_t)cleanCodeCount;
	
	if (willSaveValidatedRawString)
	{
		// Using the validated clean code string, the raw code string will be
		// rewritten using the following format for each line:
		// XXXXXXXX XXXXXXXX\n
		CheatConvertCleanCodeToRawCode(this->_cleanCodeString.c_str(), this->_rawCodeString);
	}
	else
	{
		// The passed in raw code string will be saved, regardless of any syntax
		// errors, flaws, or formatting issues that it may contain.
		this->_rawCodeString = rawString;
	}
	
	if ( (this->_cheatType == CheatType_ActionReplay) && (this->_cheatManager != NULL) && this->_isEnabled )
	{
		this->_cheatManager->MasterNeedsUpdate();
	}
	
	if (this->_cheatType == CheatType_ActionReplay)
	{
		this->_ConvertActionReplayToInternal();
	}
}

const char* ClientCheatItem::GetRawCodeString() const
{
	return this->_rawCodeString.c_str();
}

const char* ClientCheatItem::GetCleanCodeString() const
{
	return this->_cleanCodeString.c_str();
}

const std::string& ClientCheatItem::GetCleanCodeCppString() const
{
	return this->_cleanCodeString;
}

uint32_t ClientCheatItem::GetCodeCount() const
{
	return this->_codeCount;
}

void ClientCheatItem::_ConvertInternalToActionReplay()
{
	char workingCodeBuffer[16+1+1];
	
	u32 truncatedValue = this->_value;
	
	switch (this->_valueLength)
	{
		case 1:
			truncatedValue &= 0x000000FF;
			break;
			
		case 2:
			truncatedValue &= 0x0000FFFF;
			break;
			
		case 3:
			truncatedValue &= 0x00FFFFFF;
			break;
			
		default:
			break;
	}
	
	memset(workingCodeBuffer, 0, sizeof(workingCodeBuffer));
	snprintf(workingCodeBuffer, 16+1+1, "%08X %08X", this->_address, truncatedValue);
	this->_rawCodeString = workingCodeBuffer;
	
	memset(workingCodeBuffer, 0, sizeof(workingCodeBuffer));
	snprintf(workingCodeBuffer, 16+1, "%08X%08X", this->_address, truncatedValue);
	this->_cleanCodeString = workingCodeBuffer;
	
	this->_codeCount = 1;
}

void ClientCheatItem::_ConvertActionReplayToInternal()
{
	this->_addressString[0] = '0';
	this->_addressString[1] = 'x';
	strncpy(this->_addressString + 2, this->_cleanCodeString.c_str(), 8);
	this->_addressString[10] = '\0';
	sscanf(this->_addressString + 2, "%x", &this->_address);
	
	char workingCodeBuffer[9];
	memset(workingCodeBuffer, 0, sizeof(workingCodeBuffer));
	strncpy(workingCodeBuffer, this->_cleanCodeString.c_str() + 8, 8);
	sscanf(workingCodeBuffer, "%x", &this->_value);
	
	this->_valueLength = 4;
}

void ClientCheatItem::ClientToDesmumeCheatItem(CHEATS_LIST *outCheatItem) const
{
	if (outCheatItem == NULL)
	{
		return;
	}
	
	outCheatItem->type = this->_cheatType;
	outCheatItem->enabled = (this->_isEnabled) ? 1 : 0;
	strncpy(outCheatItem->description, this->_descriptionString.c_str(), sizeof(outCheatItem->description));
	
	switch (this->_cheatType)
	{
		case CheatType_Internal:
			outCheatItem->num = 1;
			outCheatItem->size = this->_valueLength - 1; // CHEATS_LIST.size value range is [1...4], but starts counting from 0.
			outCheatItem->freezeType = (u8)this->_freezeType;
			outCheatItem->code[0][0] = this->_address;
			outCheatItem->code[0][1] = this->_value;
			break;
			
		case CheatType_ActionReplay:
		case CheatType_CodeBreaker:
		{
			outCheatItem->num = this->_codeCount;
			outCheatItem->size = 3;
			outCheatItem->freezeType = CheatFreezeType_Normal;
			
			char valueString[9];
			valueString[8] = '\0';
			
			const char *cleanCodeStr = this->_cleanCodeString.c_str();
			for (size_t i = 0; i < this->_codeCount; i++)
			{
				strncpy(valueString, cleanCodeStr + (i * 16) + 0, 8);
				sscanf(valueString, "%x", &outCheatItem->code[i][0]);
				
				strncpy(valueString, cleanCodeStr + (i * 16) + 8, 8);
				sscanf(valueString, "%x", &outCheatItem->code[i][1]);
			}
			break;
		}
			
		default:
			break;
	}
}

#pragma mark -

ClientCheatList::ClientCheatList()
{
	_list = new std::vector<ClientCheatItem *>;
}

ClientCheatList::~ClientCheatList()
{
	delete this->_list;
	this->_list = NULL;
}

CheatSystemError ClientCheatList::LoadFromFile(const char *filePath)
{
	CheatSystemError error = CheatSystemError_NoError;
	
	if (filePath == NULL)
	{
		error = CheatSystemError_FileOpenFailed;
		return error;
	}
	
	CHEATS *tempEngineList = new CHEATS;
	tempEngineList->init((char *)filePath);
	this->ReplaceFromEngine(tempEngineList);
	delete tempEngineList;
	
	return error;
}

CheatSystemError ClientCheatList::SaveToFile(const char *filePath)
{
	CheatSystemError error = CheatSystemError_NoError;
	
	if (filePath == NULL)
	{
		error = CheatSystemError_FileOpenFailed;
		return error;
	}
	
	CHEATS *tempEngineList = new CHEATS;
	tempEngineList->setFilePath(filePath);
	
	this->CopyListToEngine(false, tempEngineList);
	
	bool isSaveSuccessful = tempEngineList->save();
	if (!isSaveSuccessful)
	{
		error = CheatSystemError_FileSaveFailed;
	}
	
	delete tempEngineList;
	
	return error;
}

bool ClientCheatList::IsItemDuplicate(const ClientCheatItem *srcItem)
{
	bool isDuplicateFound = false;
	if (srcItem == NULL)
	{
		return isDuplicateFound;
	}
	
	const CheatType compareType = srcItem->GetType();
	
	const size_t totalCheatCount = this->_list->size();
	for (size_t i = 0; i < totalCheatCount; i++)
	{
		const ClientCheatItem *itemToCheck = (*this->_list)[i];
		if (itemToCheck == NULL)
		{
			continue;
		}
		
		if (srcItem == itemToCheck)
		{
			isDuplicateFound = true;
			break;
		}
		
		switch (compareType)
		{
			case CheatType_Internal:
				isDuplicateFound = ( (srcItem->GetAddress()     == itemToCheck->GetAddress()) &&
				                     (srcItem->GetValue()       == itemToCheck->GetValue()) &&
				                     (srcItem->GetValueLength() == itemToCheck->GetValueLength()) );
				break;
				
			case CheatType_ActionReplay:
				isDuplicateFound = ( (srcItem->GetCodeCount()          == itemToCheck->GetCodeCount()) &&
				                     (srcItem->GetCleanCodeCppString() == itemToCheck->GetCleanCodeCppString()) );
				break;
				
			case CheatType_CodeBreaker:
			default:
				break;
		}
		
		if (isDuplicateFound)
		{
			break;
		}
	}
	
	return isDuplicateFound;
}

ClientCheatItem* ClientCheatList::__AddItem(const ClientCheatItem *srcItem, const bool willCopy, const bool allowDuplicates)
{
	ClientCheatItem *newItem = NULL;
	if (srcItem == NULL)
	{
		return newItem;
	}
	
	if (allowDuplicates || !this->IsItemDuplicate(srcItem))
	{
		if (willCopy)
		{
			this->_list->push_back(new ClientCheatItem);
			newItem->Init(*srcItem);
		}
		else
		{
			this->_list->push_back((ClientCheatItem *)srcItem);
		}
		
		newItem = this->_list->back();
	}
	
	return newItem;
}

ClientCheatItem* ClientCheatList::AddNew()
{
	ClientCheatItem *newItem = new ClientCheatItem;
	return this->__AddItem(newItem, false, true);
}

ClientCheatItem* ClientCheatList::AddNewItemCopy(const ClientCheatItem *srcItem)
{
	return this->__AddItem(srcItem, true, true);
}

ClientCheatItem* ClientCheatList::AddNewItemCopyNoDuplicate(const ClientCheatItem *srcItem)
{
	return this->__AddItem(srcItem, true, false);
}

ClientCheatItem* ClientCheatList::AddExistingItemNoDuplicate(const ClientCheatItem *srcItem)
{
	return this->__AddItem(srcItem, false, false);
}

bool ClientCheatList::Remove(ClientCheatItem *targetItem)
{
	return this->RemoveAtIndex( this->GetIndexOfItem(targetItem) );
}

bool ClientCheatList::RemoveAtIndex(size_t index)
{
	bool didRemoveItem = false;
	ClientCheatItem *targetItem = this->GetItemAtIndex(index);
	
	if (targetItem != NULL)
	{
		this->_list->erase( this->_list->begin() + index );
		delete targetItem;
		didRemoveItem = true;
	}
	
	return didRemoveItem;
}

void ClientCheatList::RemoveAll()
{
	const size_t cheatCount = this->_list->size();
	for (size_t i = 0; i < cheatCount; i++)
	{
		ClientCheatItem *itemToRemove = (*this->_list)[i];
		delete itemToRemove;
	}
	
	this->_list->clear();
}

bool ClientCheatList::Update(const ClientCheatItem &srcItem, ClientCheatItem *targetItem)
{
	return this->UpdateAtIndex(srcItem, this->GetIndexOfItem(targetItem));
}

bool ClientCheatList::UpdateAtIndex(const ClientCheatItem &srcItem, size_t index)
{
	bool didUpdateItem = false;
	ClientCheatItem *targetItem = this->GetItemAtIndex(index);
	
	if (targetItem != NULL)
	{
		targetItem->Init(srcItem);
		didUpdateItem = true;
	}
	
	return didUpdateItem;
}

size_t ClientCheatList::GetTotalCheatCount() const
{
	return this->_list->size();
}

size_t ClientCheatList::GetActiveCheatCount() const
{
	size_t activeCount = 0;
	const size_t totalCount = this->_list->size();
	
	for (size_t i = 0; i < totalCount; i++)
	{
		ClientCheatItem *cheatItem = (*this->_list)[i];
		if (cheatItem->IsEnabled())
		{
			activeCount++;
		}
	}
	
	return activeCount;
}

std::vector<ClientCheatItem *>* ClientCheatList::GetCheatList() const
{
	return this->_list;
}

size_t ClientCheatList::GetIndexOfItem(const ClientCheatItem *cheatItem) const
{
	size_t outIndex = ~0;
	if (cheatItem == NULL)
	{
		return outIndex;
	}
	
	const size_t cheatCount = this->_list->size();
	for (size_t i = 0; i < cheatCount; i++)
	{
		if (cheatItem == (*this->_list)[i])
		{
			return outIndex;
		}
	}
	
	return outIndex;
}

ClientCheatItem* ClientCheatList::GetItemAtIndex(size_t index) const
{
	if (index >= this->GetTotalCheatCount())
	{
		return NULL;
	}
	
	return (*this->_list)[index];
}

void ClientCheatList::ReplaceFromEngine(const CHEATS *engineCheatList)
{
	if (engineCheatList == NULL)
	{
		return;
	}
	
	this->RemoveAll();
	
	const size_t totalCount = engineCheatList->getListSize();
	for (size_t i = 0; i < totalCount; i++)
	{
		ClientCheatItem *newItem = this->AddNew();
		newItem->Init( *engineCheatList->getItemPtrAtIndex(i) );
	}
}

void ClientCheatList::CopyListToEngine(const bool willApplyOnlyEnabledItems, CHEATS *engineCheatList)
{
	if (engineCheatList == NULL)
	{
		return;
	}
	
	CHEATS_LIST tempEngineItem;
	
	engineCheatList->clear();
	
	const size_t totalCount = this->_list->size();
	for (size_t i = 0; i < totalCount; i++)
	{
		ClientCheatItem *cheatItem = (*this->_list)[i];
		if (cheatItem->IsEnabled() || !willApplyOnlyEnabledItems)
		{
			cheatItem->ClientToDesmumeCheatItem(&tempEngineItem);
			engineCheatList->addItem(tempEngineItem);
		}
	}
}

#pragma mark -

ClientCheatManager::ClientCheatManager()
{
	_workingList = new ClientCheatList;
	_databaseList = new ClientCheatList;
	
	_selectedItem = NULL;
	_selectedItemIndex = 0;
	
	_untitledCount = 0;
	
	_databaseTitle.resize(0);
	_databaseDate.resize(0);
	_lastFilePath.resize(0);
	
	_masterNeedsUpdate = true;
}

ClientCheatManager::~ClientCheatManager()
{
	delete this->_databaseList;
	delete this->_workingList;
}

CHEATS* ClientCheatManager::GetMaster()
{
	return cheats;
}

void ClientCheatManager::SetMaster(const CHEATS *masterCheats)
{
	cheats = (CHEATS *)masterCheats;
}

ClientCheatList* ClientCheatManager::GetWorkingList() const
{
	return this->_workingList;
}

ClientCheatList* ClientCheatManager::GetDatabaseList() const
{
	return this->_databaseList;
}

const char* ClientCheatManager::GetDatabaseTitle() const
{
	return this->_databaseTitle.c_str();
}

void ClientCheatManager::SetDatabaseTitle(const char *dbTitle)
{
	if (dbTitle != NULL)
	{
		this->_databaseTitle = dbTitle;
	}
}

const char* ClientCheatManager::GetDatabaseDate() const
{
	return this->_databaseDate.c_str();
}

void ClientCheatManager::SetDatabaseDate(const char *dbDate)
{
	if (dbDate != NULL)
	{
		this->_databaseDate = dbDate;
	}
}

const char* ClientCheatManager::GetLastFilePath() const
{
	return this->_lastFilePath.c_str();
}

CheatSystemError ClientCheatManager::LoadFromFile(const char *filePath)
{
	CheatSystemError error = CheatSystemError_NoError;
	
	if (filePath == NULL)
	{
		error = CheatSystemError_FileOpenFailed;
		return error;
	}
	
	error = this->_workingList->LoadFromFile(filePath);
	if (error == CheatSystemError_NoError)
	{
		this->_lastFilePath = filePath;
		
		const size_t totalCount = this->_workingList->GetTotalCheatCount();
		for (size_t i = 0; i < totalCount; i++)
		{
			ClientCheatItem *cheatItem = this->_workingList->GetItemAtIndex(i);
			cheatItem->SetCheatManager(this);
		}
	}
	
	return error;
}

CheatSystemError ClientCheatManager::SaveToFile(const char *filePath)
{
	CheatSystemError error = CheatSystemError_NoError;
	
	if (filePath == NULL)
	{
		error = CheatSystemError_FileSaveFailed;
		return error;
	}
	
	error = this->_workingList->SaveToFile(filePath);
	if (error == CheatSystemError_NoError)
	{
		this->_lastFilePath = filePath;
	}
	
	return error;
}

ClientCheatItem* ClientCheatManager::SetSelectedItemByIndex(size_t index)
{
	this->_selectedItemIndex = index;
	this->_selectedItem = this->_workingList->GetItemAtIndex(index);
	
	return this->_selectedItem;
}

ClientCheatItem* ClientCheatManager::NewItem()
{
	ClientCheatItem *newItem = this->_workingList->AddNew();
	newItem->SetCheatManager(this);
	
	this->_untitledCount++;
	if (this->_untitledCount > 1)
	{
		char newDesc[16];
		snprintf(newDesc, sizeof(newDesc), "Untitled %ld", (unsigned long)this->_untitledCount);
		
		newItem->SetDescription(newDesc);
	}
	else
	{
		newItem->SetDescription("Untitled");
	}
	
	if (newItem->IsEnabled())
	{
		this->_masterNeedsUpdate = true;
	}
	
	return newItem;
}

ClientCheatItem* ClientCheatManager::AddExistingItemNoDuplicate(const ClientCheatItem *theItem)
{
	ClientCheatItem *addedItem = this->_workingList->AddExistingItemNoDuplicate(theItem);
	if (addedItem != NULL)
	{
		addedItem->SetCheatManager(this);
		
		if (addedItem->IsEnabled())
		{
			this->_masterNeedsUpdate = true;
		}
	}
	
	return addedItem;
}

void ClientCheatManager::RemoveItem(ClientCheatItem *targetItem)
{
	this->RemoveItemAtIndex( this->_workingList->GetIndexOfItem(targetItem) );
}

void ClientCheatManager::RemoveItemAtIndex(size_t index)
{
	const ClientCheatItem *targetItem = this->_workingList->GetItemAtIndex(index);
	if (targetItem == NULL)
	{
		return;
	}
	
	const bool willChangeMasterUpdateFlag = targetItem->IsEnabled();
	const bool didRemoveItem = this->_workingList->RemoveAtIndex(index);
	
	if (didRemoveItem && willChangeMasterUpdateFlag)
	{
		this->_masterNeedsUpdate = true;
	}
}

void ClientCheatManager::RemoveSelectedItem()
{
	this->RemoveItemAtIndex(this->_selectedItemIndex);
}

void ClientCheatManager::ModifyItem(const ClientCheatItem *srcItem, ClientCheatItem *targetItem)
{
	if ( (srcItem != NULL) && (srcItem == targetItem) )
	{
		if (targetItem->IsEnabled())
		{
			this->_masterNeedsUpdate = true;
		}
		return;
	}
	
	this->ModifyItemAtIndex(srcItem, this->_workingList->GetIndexOfItem(targetItem));
}

void ClientCheatManager::ModifyItemAtIndex(const ClientCheatItem *srcItem, size_t index)
{
	const ClientCheatItem *targetItem = this->_workingList->GetItemAtIndex(index);
	if ( (srcItem == NULL) || (targetItem == NULL) )
	{
		return;
	}
	
	const bool willChangeMasterUpdateFlag = targetItem->IsEnabled();
	const bool didModifyItem = this->_workingList->UpdateAtIndex(*srcItem, index);
	
	if (didModifyItem && willChangeMasterUpdateFlag)
	{
		this->_masterNeedsUpdate = true;
	}
}

size_t ClientCheatManager::GetTotalCheatCount() const
{
	return this->_workingList->GetTotalCheatCount();
}

size_t ClientCheatManager::GetActiveCheatCount() const
{
	return this->_workingList->GetActiveCheatCount();
}

ClientCheatList* ClientCheatManager::LoadFromDatabase(const char *dbFilePath)
{
	if (dbFilePath == NULL)
	{
		return NULL;
	}
	
	CHEATSEXPORT *exporter = new CHEATSEXPORT();
	CheatSystemError dbError = CheatSystemError_NoError;
	
	bool didFileLoad = exporter->load((char *)dbFilePath);
	if (didFileLoad)
	{
		this->_databaseList->RemoveAll();
		
		this->SetDatabaseTitle((const char *)exporter->gametitle);
		this->SetDatabaseDate((const char *)exporter->date);
		
		const size_t itemCount = exporter->getCheatsNum();
		const CHEATS_LIST *dbItem = exporter->getCheats();
		
		for (size_t i = 0; i < itemCount; i++)
		{
			ClientCheatItem *newItem = this->_databaseList->AddNew();
			if (newItem != NULL)
			{
				newItem->Init(dbItem[i]);
			}
		}
	}
	else
	{
		dbError = (CheatSystemError)exporter->getErrorCode();
	}

	delete exporter;
	exporter = nil;
	
	if (dbError != CheatSystemError_NoError)
	{
		return NULL;
	}
	
	return this->_databaseList;
}

void ClientCheatManager::LoadFromMaster()
{
	size_t activeCount = 0;
	const CHEATS *masterCheats = ClientCheatManager::GetMaster();
	
	if (masterCheats == NULL)
	{
		return;
	}
	
	this->_lastFilePath = masterCheats->getFilePath();
	
	activeCount = this->_workingList->GetActiveCheatCount();
	if (activeCount > 0)
	{
		this->_masterNeedsUpdate = true;
	}
	
	this->_workingList->ReplaceFromEngine(masterCheats);
	
	const size_t totalCount = this->_workingList->GetTotalCheatCount();
	for (size_t i = 0; i < totalCount; i++)
	{
		ClientCheatItem *cheatItem = this->_workingList->GetItemAtIndex(i);
		cheatItem->SetCheatManager(this);
	}
	
	activeCount = this->_workingList->GetActiveCheatCount();
	if (activeCount > 0)
	{
		this->_masterNeedsUpdate = true;
	}
}

void ClientCheatManager::ApplyToMaster()
{
	CHEATS *masterCheats = ClientCheatManager::GetMaster();
	if ( (masterCheats == NULL) || !this->_masterNeedsUpdate )
	{
		return;
	}
	
	this->_workingList->CopyListToEngine(true, masterCheats);
	this->_masterNeedsUpdate = false;
}

void ClientCheatManager::MasterNeedsUpdate()
{
	this->_masterNeedsUpdate = true;
}

void ClientCheatManager::ApplyInternalCheatAtIndex(size_t index)
{
	ClientCheatManager::ApplyInternalCheatWithItem( this->_workingList->GetItemAtIndex(index) );
}

void ClientCheatManager::ApplyInternalCheatWithItem(const ClientCheatItem *cheatItem)
{
	if ( (cheatItem == NULL) || (cheatItem->GetType() != CheatType_Internal) )
	{
		return;
	}
	
	ClientCheatManager::ApplyInternalCheatWithParams( cheatItem->GetAddress(), cheatItem->GetValue(), cheatItem->GetValueLength() );
}

void ClientCheatManager::ApplyInternalCheatWithParams(uint32_t targetAddress, uint32_t newValue, size_t newValueLength)
{
	targetAddress &= 0x00FFFFFF;
	targetAddress |= 0x02000000;
	
	switch (newValueLength)
	{
		case 1:
		{
			u8 oneByteValue = (u8)(newValue & 0x000000FF);
			_MMU_write08<ARMCPU_ARM9,MMU_AT_DEBUG>(targetAddress, oneByteValue);
			break;
		}
			
		case 2:
		{
			u16 twoByteValue = (u16)(newValue & 0x0000FFFF);
			_MMU_write16<ARMCPU_ARM9,MMU_AT_DEBUG>(targetAddress, twoByteValue);
			break;
		}
			
		case 3:
		{
			u32 threeByteWithExtraValue = _MMU_read32<ARMCPU_ARM9,MMU_AT_DEBUG>(targetAddress);
			threeByteWithExtraValue &= 0xFF000000;
			threeByteWithExtraValue |= (newValue & 0x00FFFFFF);
			_MMU_write32<ARMCPU_ARM9,MMU_AT_DEBUG>(targetAddress, threeByteWithExtraValue);
			break;
		}
			
		case 4:
			_MMU_write32<ARMCPU_ARM9,MMU_AT_DEBUG>(targetAddress, newValue);
			break;
			
		default:
			break;
	}
}

#pragma mark -

@implementation CocoaDSCheatItem

static NSImage *iconInternalCheat = nil;
static NSImage *iconActionReplay = nil;
static NSImage *iconCodeBreaker = nil;

@synthesize _internalData;
@synthesize willAdd;
@dynamic enabled;
@dynamic cheatType;
@dynamic cheatTypeIcon;
@dynamic isSupportedCheatType;
@dynamic freezeType;
@dynamic description;
@dynamic codeCount;
@dynamic code;
@dynamic memAddress;
@dynamic memAddressString;
@dynamic memAddressSixDigitString;
@dynamic bytes;
@dynamic value;
@synthesize workingCopy;
@synthesize parent;

- (id)init
{
	return [self initWithCheatItem:NULL];
}

- (id) initWithCocoaCheatItem:(CocoaDSCheatItem *)cdsCheatItem
{
	return [self initWithCheatItem:[cdsCheatItem clientData]];
}

- (id) initWithCheatItem:(ClientCheatItem *)cheatItem
{
	self = [super init];
	if(self == nil)
	{
		return self;
	}
	
	if (cheatItem == NULL)
	{
		_internalData = new ClientCheatItem;
		_didAllocateInternalData = YES;
	}
	else
	{
		_internalData = cheatItem;
		_didAllocateInternalData = NO;
	}
	
	_disableWorkingCopyUpdate = NO;
	willAdd = NO;
	workingCopy = nil;
	parent = nil;
	_isMemAddressAlreadyUpdating = NO;
	
	return self;
}

- (id) initWithCheatData:(const CHEATS_LIST *)cheatData
{
	self = [super init];
	if(self == nil)
	{
		return self;
	}
	
	_internalData = new ClientCheatItem;
	_didAllocateInternalData = YES;
	
	if (cheatData != NULL)
	{
		_internalData->Init(*cheatData);
	}
	
	willAdd = NO;
	workingCopy = nil;
	parent = nil;
	_isMemAddressAlreadyUpdating = NO;
	
	return self;
}

- (void) dealloc
{
	[self destroyWorkingCopy];
	
	if (_didAllocateInternalData)
	{
		delete _internalData;
		_internalData = NULL;
	}
	
	[super dealloc];
}

- (BOOL) enabled
{
	return _internalData->IsEnabled() ? YES : NO;
}

- (void) setEnabled:(BOOL)theState
{
	_internalData->SetEnabled((theState) ? true : false);
	
	if ((workingCopy != nil) && !_disableWorkingCopyUpdate)
	{
		[workingCopy setEnabled:theState];
	}
}

- (NSString *) description
{
	return [NSString stringWithCString:_internalData->GetDescription() encoding:NSUTF8StringEncoding];
}

- (void) setDescription:(NSString *)desc
{
	if (desc == nil)
	{
		_internalData->SetDescription(NULL);
	}
	else
	{
		_internalData->SetDescription([desc cStringUsingEncoding:NSUTF8StringEncoding]);
	}
	
	if ((workingCopy != nil) && !_disableWorkingCopyUpdate)
	{
		[workingCopy setDescription:desc];
	}
}

- (char *) descriptionCString
{
	return (char *)_internalData->GetDescription();
}

- (NSInteger) cheatType
{
	return (NSInteger)_internalData->GetType();
}

- (void) setCheatType:(NSInteger)theType
{
	_internalData->SetType((CheatType)theType);
	
	switch (theType)
	{
		case CHEAT_TYPE_INTERNAL:
			[self setCheatTypeIcon:iconInternalCheat];
			[self setIsSupportedCheatType:YES];
			[self setMemAddress:[self memAddress]];
			[self setValue:[self value]];
			[self setBytes:[self bytes]];
			break;
			
		case CHEAT_TYPE_ACTION_REPLAY:
			[self setCheatTypeIcon:iconActionReplay];
			[self setIsSupportedCheatType:YES];
			[self setCode:[self code]];
			break;
			
		case CHEAT_TYPE_CODE_BREAKER:
			[self setCheatTypeIcon:iconCodeBreaker];
			[self setIsSupportedCheatType:NO];
			[self setCode:[self code]];
			break;
			
		default:
			break;
	}
	
	if ((workingCopy != nil) && !_disableWorkingCopyUpdate)
	{
		[workingCopy setCheatType:theType];
	}
}

- (void) setCheatTypeIcon:(NSImage *)theIcon
{
	// Do nothing. This method exists for KVO compliance only.
}

- (NSImage *) cheatTypeIcon
{
	NSImage *theIcon = nil;
	
	switch ([self cheatType])
	{
		case CHEAT_TYPE_INTERNAL:
			theIcon = iconInternalCheat;
			break;
			
		case CHEAT_TYPE_ACTION_REPLAY:
			theIcon = iconActionReplay;
			break;
			
		case CHEAT_TYPE_CODE_BREAKER:
			theIcon = iconCodeBreaker;
			break;
			
		default:
			break;
	}
	
	return theIcon;
}

- (BOOL) isSupportedCheatType
{
	return (_internalData->IsSupportedType()) ? YES : NO;
}

- (void) setIsSupportedCheatType:(BOOL)isSupported
{
	// Do nothing. This method exists for KVO compliance only.
}

- (NSInteger) freezeType
{
	return (NSInteger)_internalData->GetFreezeType();
}

- (void) setFreezeType:(NSInteger)theType
{
	_internalData->SetFreezeType((CheatFreezeType)theType);
	
	if ((workingCopy != nil) && !_disableWorkingCopyUpdate)
	{
		[workingCopy setFreezeType:theType];
	}
}

- (UInt8) bytes
{
	return _internalData->GetValueLength();
}

- (void) setBytes:(UInt8)byteSize
{
	_internalData->SetValueLength(byteSize);
	
	if ((workingCopy != nil) && !_disableWorkingCopyUpdate)
	{
		[workingCopy setBytes:byteSize];
	}
}

- (NSUInteger) codeCount
{
	return (NSUInteger)_internalData->GetCodeCount();
}

- (void) setCodeCount:(NSUInteger)count
{
	// Do nothing. This method exists for KVO compliance only.
}

- (NSString *) code
{
	return [NSString stringWithCString:_internalData->GetRawCodeString() encoding:NSUTF8StringEncoding];
}

- (void) setCode:(NSString *)theCode
{
	if (theCode == nil)
	{
		return;
	}
	
	_internalData->SetRawCodeString([theCode cStringUsingEncoding:NSUTF8StringEncoding], true);
	
	[self setCodeCount:[self codeCount]];
	[self setBytes:[self bytes]];
	
	if ((workingCopy != nil) && !_disableWorkingCopyUpdate)
	{
		[workingCopy setCode:theCode];
	}
}

- (UInt32) memAddress
{
	return _internalData->GetAddress();
}

- (void) setMemAddress:(UInt32)theAddress
{
	theAddress &= 0x00FFFFFF;
	theAddress |= 0x02000000;
	
	_internalData->SetAddress(theAddress);
	
	if (!_isMemAddressAlreadyUpdating)
	{
		_isMemAddressAlreadyUpdating = YES;
		NSString *addrString = [NSString stringWithCString:_internalData->GetAddressSixDigitString() encoding:NSUTF8StringEncoding];
		[self setMemAddressSixDigitString:addrString];
		_isMemAddressAlreadyUpdating = NO;
	}
	
	if ((workingCopy != nil) && !_disableWorkingCopyUpdate)
	{
		[workingCopy setMemAddress:theAddress];
	}
}

- (NSString *) memAddressString
{
	return [NSString stringWithCString:_internalData->GetAddressString() encoding:NSUTF8StringEncoding];
}

- (void) setMemAddressString:(NSString *)addressString
{
	if (!_isMemAddressAlreadyUpdating)
	{
		_isMemAddressAlreadyUpdating = YES;
		u32 address = 0x00000000;
		[[NSScanner scannerWithString:addressString] scanHexInt:&address];
		[self setMemAddress:address];
		_isMemAddressAlreadyUpdating = NO;
	}
	
	if ((workingCopy != nil) && !_disableWorkingCopyUpdate)
	{
		[workingCopy setMemAddressString:addressString];
	}
}

- (NSString *) memAddressSixDigitString
{
	return [NSString stringWithCString:_internalData->GetAddressSixDigitString() encoding:NSUTF8StringEncoding];
}

- (void) setMemAddressSixDigitString:(NSString *)addressString
{
	[self setMemAddressString:addressString];
}

- (SInt64) value
{
	return _internalData->GetValue();
}

- (void) setValue:(SInt64)theValue
{
	_internalData->SetValue((u32)theValue);
	
	if ((workingCopy != nil) && !_disableWorkingCopyUpdate)
	{
		[workingCopy setValue:theValue];
	}
}

- (void) update
{
	[self setEnabled:[self enabled]];
	[self setDescription:[self description]];
	[self setCheatType:[self cheatType]];
	[self setFreezeType:[self freezeType]];
	
	if ([self cheatType] == CHEAT_TYPE_INTERNAL)
	{
		[self setMemAddressSixDigitString:[self memAddressSixDigitString]];
		[self setValue:[self value]];
		[self setBytes:[self bytes]];
	}
	else
	{
		[self setCode:[self code]];
	}
}

- (void) copyFrom:(CocoaDSCheatItem *)cdsCheatItem
{
	if (cdsCheatItem == nil)
	{
		return;
	}
	
	if (cdsCheatItem == workingCopy)
	{
		_disableWorkingCopyUpdate = YES;
	}
	
	[self setEnabled:[cdsCheatItem enabled]];
	[self setDescription:[cdsCheatItem description]];
	[self setCheatType:[cdsCheatItem cheatType]];
	[self setFreezeType:[cdsCheatItem freezeType]];
	
	if ([self cheatType] == CHEAT_TYPE_INTERNAL)
	{
		[self setMemAddress:[cdsCheatItem memAddress]];
		[self setValue:[cdsCheatItem value]];
		[self setBytes:[cdsCheatItem bytes]];
	}
	else
	{
		[self setCode:[cdsCheatItem code]];
	}
	
	_disableWorkingCopyUpdate = NO;
}

- (CocoaDSCheatItem *) createWorkingCopy
{
	CocoaDSCheatItem *newWorkingCopy = nil;
	
	if (workingCopy != nil)
	{
		[workingCopy release];
	}
	
	newWorkingCopy = [[CocoaDSCheatItem alloc] init];
	ClientCheatItem *workingCheat = [newWorkingCopy clientData];
	workingCheat->Init(*[self clientData]);
	
	[newWorkingCopy setParent:self];
	workingCopy = newWorkingCopy;
	
	return newWorkingCopy;
}

- (void) destroyWorkingCopy
{
	[workingCopy release];
	workingCopy = nil;
}

- (void) mergeToParent
{
	if (parent == nil)
	{
		return;
	}
	
	[parent copyFrom:self];
}

+ (void) setIconInternalCheat:(NSImage *)iconImage
{
	iconInternalCheat = iconImage;
}

+ (NSImage *) iconInternalCheat
{
	return iconInternalCheat;
}

+ (void) setIconActionReplay:(NSImage *)iconImage
{
	iconActionReplay = iconImage;
}

+ (NSImage *) iconActionReplay
{
	return iconActionReplay;
}

+ (void) setIconCodeBreaker:(NSImage *)iconImage
{
	iconCodeBreaker = iconImage;
}

+ (NSImage *) iconCodeBreaker
{
	return iconCodeBreaker;
}

@end


@implementation CocoaDSCheatManager

@synthesize _internalCheatManager;
@synthesize list;
@dynamic dbTitle;
@dynamic dbDate;

- (id)init
{
	return [self initWithFileURL:nil];
}

- (id) initWithFileURL:(NSURL *)fileURL
{
	self = [super init];
	if(self == nil)
	{
		return self;
	}
	
	_internalCheatManager = new ClientCheatManager;
	
	if (fileURL != nil)
	{
		_internalCheatManager->LoadFromFile([CocoaDSUtil cPathFromFileURL:fileURL]);
		
		ClientCheatList *clientList = _internalCheatManager->GetWorkingList();
		list = [[CocoaDSCheatManager cheatListWithClientListObject:clientList] retain];
	}
	else
	{
		list = [[NSMutableArray alloc] initWithCapacity:100];
		if (list == nil)
		{
			delete _internalCheatManager;
			[self release];
			return nil;
		}
	}
	
	return self;
}

- (void)dealloc
{
	[list release];
	list = nil;
	
	delete _internalCheatManager;
	_internalCheatManager = NULL;
	
	[super dealloc];
}

- (NSString *) dbTitle
{
	return [NSString stringWithCString:_internalCheatManager->GetDatabaseTitle() encoding:NSUTF8StringEncoding];
}

- (void) setDbTitle:(NSString *)theString
{
	// Do nothing. This method exists for KVO compliance only.
}

- (NSString *) dbDate
{
	return [NSString stringWithCString:_internalCheatManager->GetDatabaseDate() encoding:NSUTF8StringEncoding];
}

- (void) setDbDate:(NSString *)theString
{
	// Do nothing. This method exists for KVO compliance only.
}

- (CocoaDSCheatItem *) newItem
{
	CocoaDSCheatItem *newCocoaItem = nil;
	
	ClientCheatItem *newItem = _internalCheatManager->NewItem();
	if (newItem == NULL)
	{
		return newCocoaItem;
	}
	
	newCocoaItem = [[CocoaDSCheatItem alloc] initWithCheatItem:newItem];
	if (newCocoaItem == nil)
	{
		delete newItem;
		newItem = NULL;
	}
	
	return newCocoaItem;
}

- (BOOL) addExistingItem:(CocoaDSCheatItem *)cheatItem
{
	BOOL result = NO;
	
	if ( (cheatItem == nil) || [[self list] containsObject:cheatItem] )
	{
		return result;
	}
	
	ClientCheatItem *addedItem = _internalCheatManager->AddExistingItemNoDuplicate([cheatItem clientData]);
	if (addedItem == NULL)
	{
		return result;
	}
	
	result = YES;
	return result;
}

- (void) remove:(CocoaDSCheatItem *)cheatItem
{
	if (cheatItem == nil)
	{
		return;
	}
	
	NSUInteger selectionIndex = [[self list] indexOfObject:cheatItem];
	if (selectionIndex == NSNotFound)
	{
		return;
	}
	
	_internalCheatManager->RemoveItemAtIndex(selectionIndex);
}

- (BOOL) update:(CocoaDSCheatItem *)cheatItem
{
	BOOL result = NO;
	
	if (cheatItem == nil)
	{
		return result;
	}
	
	_internalCheatManager->ModifyItem([cheatItem clientData], [cheatItem clientData]);
	[cheatItem update];
	
	result = YES;
	return result;
}

- (BOOL) save
{
	const char *lastFilePath = _internalCheatManager->GetLastFilePath();
	const CheatSystemError error = _internalCheatManager->SaveToFile(lastFilePath);
	
	return (error == CheatSystemError_NoError) ? YES : NO;
}

- (NSUInteger) activeCount
{
	return (NSUInteger)_internalCheatManager->GetActiveCheatCount();
}

- (NSMutableArray *) cheatListFromDatabase:(NSURL *)fileURL errorCode:(NSInteger *)error
{
	NSMutableArray *newCocoaDBList = nil;
	
	if (fileURL == nil)
	{
		return newCocoaDBList;
	}
	
	ClientCheatList *dbList = _internalCheatManager->LoadFromDatabase([CocoaDSUtil cPathFromFileURL:fileURL]);
	if (dbList != NULL)
	{
		newCocoaDBList = [CocoaDSCheatManager cheatListWithClientListObject:dbList];
	}
	
	return newCocoaDBList;
}

- (void) applyInternalCheat:(CocoaDSCheatItem *)cheatItem
{
	if (cheatItem == nil)
	{
		return;
	}
	
	ClientCheatManager::ApplyInternalCheatWithItem([cheatItem clientData]);
}

- (void) loadFromMaster
{
	CHEATS *masterCheats = ClientCheatManager::GetMaster();
	if (masterCheats != NULL)
	{
		_internalCheatManager->LoadFromMaster();
		
		if (list != nil)
		{
			[list release];
		}
		
		ClientCheatList *clientList = _internalCheatManager->GetWorkingList();
		list = [[CocoaDSCheatManager cheatListWithClientListObject:clientList] retain];
	}
}

- (void) applyToMaster
{
	_internalCheatManager->ApplyToMaster();
}

+ (NSMutableArray *) cheatListWithClientListObject:(ClientCheatList *)cheatList
{
	if (cheatList == NULL)
	{
		return nil;
	}
	
	NSMutableArray *newList = [NSMutableArray arrayWithCapacity:100];
	if (newList == nil)
	{
		return newList;
	}
	
	const size_t itemCount = cheatList->GetTotalCheatCount();
	for (size_t i = 0; i < itemCount; i++)
	{
		CocoaDSCheatItem *cheatItem = [[CocoaDSCheatItem alloc] initWithCheatItem:cheatList->GetItemAtIndex(i)];
		if (cheatItem != nil)
		{
			[newList addObject:[cheatItem autorelease]];
		}
	}
	
	return newList;
}

@end

@implementation CocoaDSCheatSearch

@synthesize listData;
@synthesize addressList;
@dynamic rwlockCoreExecute;
@synthesize searchCount;

- (id)init
{
	self = [super init];
	if(self == nil)
	{
		return self;
	}
	
	CHEATSEARCH *newListData = new CHEATSEARCH();
	if (newListData == nil)
	{
		[self release];
		return nil;
	}
	
	rwlockCoreExecute = (pthread_rwlock_t *)malloc(sizeof(pthread_rwlock_t));
	pthread_rwlock_init(rwlockCoreExecute, NULL);
	isUsingDummyRWlock = YES;
	
	listData = newListData;
	addressList = nil;
	searchCount = 0;
	
	return self;
}

- (void)dealloc
{
	pthread_rwlock_wrlock([self rwlockCoreExecute]);
	[self listData]->close();
	pthread_rwlock_unlock([self rwlockCoreExecute]);
	
	[addressList release];
	delete (CHEATSEARCH *)[self listData];
	
	if (isUsingDummyRWlock)
	{
		pthread_rwlock_destroy(rwlockCoreExecute);
		free(rwlockCoreExecute);
		rwlockCoreExecute = NULL;
	}
	
	[super dealloc];
}

- (void) setRwlockCoreExecute:(pthread_rwlock_t *)theRwlock
{
	if (theRwlock == NULL && isUsingDummyRWlock)
	{
		return;
	}
	else if (theRwlock == NULL && !isUsingDummyRWlock)
	{
		rwlockCoreExecute = (pthread_rwlock_t *)malloc(sizeof(pthread_rwlock_t));
		pthread_rwlock_init(rwlockCoreExecute, NULL);
		isUsingDummyRWlock = YES;
		return;
	}
	else if (theRwlock != NULL && isUsingDummyRWlock)
	{
		pthread_rwlock_destroy(rwlockCoreExecute);
		free(rwlockCoreExecute);
		isUsingDummyRWlock = NO;
		rwlockCoreExecute = theRwlock;
	}
	else if (theRwlock != NULL && !isUsingDummyRWlock)
	{
		rwlockCoreExecute = theRwlock;
	}
}

- (pthread_rwlock_t *) rwlockCoreExecute
{
	return rwlockCoreExecute;
}

- (NSUInteger) runExactValueSearch:(NSInteger)value byteSize:(UInt8)byteSize signType:(NSInteger)signType
{
	NSUInteger itemCount = 0;
	BOOL listExists = YES;
	
	if (searchCount == 0)
	{
		byteSize--;
		
		pthread_rwlock_rdlock([self rwlockCoreExecute]);
		listExists = (NSUInteger)[self listData]->start((u8)CHEATSEARCH_SEARCHSTYLE_EXACT_VALUE, (u8)byteSize, (u8)signType);
		pthread_rwlock_unlock([self rwlockCoreExecute]);
	}
	
	if (listExists)
	{
		pthread_rwlock_rdlock([self rwlockCoreExecute]);
		itemCount = (NSUInteger)[self listData]->search((u32)value);
		NSMutableArray *newAddressList = [[CocoaDSCheatSearch addressListWithListObject:[self listData] maxItems:100] retain];
		pthread_rwlock_unlock([self rwlockCoreExecute]);
		
		[addressList release];
		addressList = newAddressList;
		searchCount++;
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"org.desmume.DeSmuME.searchDidFinish" object:self userInfo:nil];
	
	return itemCount;
}

- (void) runExactValueSearchOnThread:(id)object
{
	CocoaDSCheatSearchParams *searchParams = (CocoaDSCheatSearchParams *)object;
	[self runExactValueSearch:[searchParams value] byteSize:[searchParams byteSize] signType:[searchParams signType]];
}

- (NSUInteger) runComparativeSearch:(NSInteger)typeID byteSize:(UInt8)byteSize signType:(NSInteger)signType
{
	NSUInteger itemCount = 0;
	BOOL listExists = YES;
	
	if (searchCount == 0)
	{
		byteSize--;
		
		pthread_rwlock_rdlock([self rwlockCoreExecute]);
		listExists = (NSUInteger)[self listData]->start((u8)CHEATSEARCH_SEARCHSTYLE_COMPARATIVE, (u8)byteSize, (u8)signType);
		pthread_rwlock_unlock([self rwlockCoreExecute]);
		
		addressList = nil;
	}
	else
	{
		pthread_rwlock_rdlock([self rwlockCoreExecute]);
		itemCount = (NSUInteger)[self listData]->search((u8)typeID);
		NSMutableArray *newAddressList = [[CocoaDSCheatSearch addressListWithListObject:[self listData] maxItems:100] retain];
		pthread_rwlock_unlock([self rwlockCoreExecute]);
		
		[addressList release];
		addressList = newAddressList;
	}

	if (listExists)
	{
		searchCount++;
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"org.desmume.DeSmuME.searchDidFinish" object:self userInfo:nil];
	
	return itemCount;
}

- (void) runComparativeSearchOnThread:(id)object
{
	CocoaDSCheatSearchParams *searchParams = (CocoaDSCheatSearchParams *)object;
	[self runComparativeSearch:[searchParams comparativeSearchType] byteSize:[searchParams byteSize] signType:[searchParams signType]];
}

- (void) reset
{
	pthread_rwlock_wrlock([self rwlockCoreExecute]);
	[self listData]->close();
	pthread_rwlock_unlock([self rwlockCoreExecute]);
	
	searchCount = 0;
	[addressList release];
	addressList = nil;
}

+ (NSMutableArray *) addressListWithListObject:(CHEATSEARCH *)addressList maxItems:(NSUInteger)maxItemCount
{
	if (addressList == nil)
	{
		return nil;
	}
	
	if (maxItemCount == 0)
	{
		maxItemCount = 1024 * 1024 * 4;
	}
	
	NSMutableArray *newList = [NSMutableArray arrayWithCapacity:maxItemCount];
	if (newList == nil)
	{
		return newList;
	}
	
	NSMutableDictionary *newItem = nil;
	NSUInteger listCount = 0;
	u32 address;
	u32 value;
	
	addressList->getListReset();
	while (addressList->getList(&address, &value) && listCount < maxItemCount)
	{
		newItem = [NSMutableDictionary dictionaryWithObjectsAndKeys:
				   [NSString stringWithFormat:@"0x02%06X", address], @"addressString",
				   [NSNumber numberWithUnsignedInteger:value], @"value",
				   nil];
		
		[newList addObject:newItem];
		listCount++;
	}
	
	return newList;
}

@end

@implementation CocoaDSCheatSearchParams

@synthesize comparativeSearchType;
@synthesize value;
@synthesize byteSize;
@synthesize signType;

- (id)init
{
	self = [super init];
	if(self == nil)
	{
		return self;
	}
	
	comparativeSearchType = CHEATSEARCH_COMPARETYPE_EQUALS_TO;
	value = 1;
	byteSize = 4;
	signType = CHEATSEARCH_UNSIGNED;
	
	return self;
}

@end
