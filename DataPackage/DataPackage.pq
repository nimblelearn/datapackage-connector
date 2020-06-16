/*
MIT License

Copyright (c) 2018-2020 Nimble Learn Ltd (http://www.nimblelearn.com)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

[Version = "1.1.0"]
section DataPackage;

//
// Definitions
//

// Data Source Kind description
DataPackage = [
    TestConnection = (dataSourcePath) => 
        let
            // dataSourcePath returns a JSON object with the parameters so we need to map them back to variables
            json = Json.Document(dataSourcePath),
            dataPackageIdentifier = json[dataPackageIdentifier],
            ignoreTableSchemaTypes = json[ignoreTableSchemaTypes]
        in 
            {"DataPackage.Load", dataPackageIdentifier, ignoreTableSchemaTypes},
    Authentication = [
        Implicit = []
    ]/*,
    Label = Extension.LoadString("DataSourceLabel")*/ // This is commented out because it hides the data source path when used
];

// Data Source UI publishing description
DataPackage.Publish = [
    Beta = false,
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") }, // ButtonText controls the 'Get Data' UI button text. The first item in the list defines the name of the button and the second controls the tooltip.
    LearnMoreUrl = Extension.LoadString("LearnMoreUrl"),
    SourceImage = DataPackage.Icons,
    SourceTypeImage = DataPackage.Icons
];

DataPackage.Icons = [
    Icon16 = { Extension.Contents("Frictionless16.png"), Extension.Contents("Frictionless20.png"), Extension.Contents("Frictionless24.png"), Extension.Contents("Frictionless32.png") },
    Icon32 = { Extension.Contents("Frictionless32.png"), Extension.Contents("Frictionless40.png"), Extension.Contents("Frictionless48.png"), Extension.Contents("Frictionless64.png") }
];

//
// Implementation
//
// Function definition for loading M modules
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

// Load the DataPackage.Tables module

shared DataPackage.Helper = Extension.LoadFunction("DataPackageHelper.pqm");
shared DataPackage.Table = Extension.LoadFunction("DataPackageTable.pqm");
shared DataPackage.Tables = Extension.LoadFunction("DataPackageTables.pqm");


[DataSource.Kind="DataPackage", Publish="DataPackage.Publish"]
shared DataPackage.Load = Value.ReplaceType(DataPackage.LoadContents, DataPackage.LoadContentsWithDocumentation);



DataPackage.LoadContentsWithDocumentation = type function (
    dataPackageIdentifier as (
                                       type text meta [
                                           Documentation.FieldCaption = "Data Package Identifier"
                                           //Documentation.FieldDescription = "A valid Data Package Identifier",
                                           //Documentation.SampleValues = {"https://datahub.io/core/gdp/datapackage.json"}
                                       ]
                                   ),
    ignoreTableSchemaTypes as (
                                       type text meta [
                                           Documentation.FieldCaption = "Ignore Table Schema Types"
                                           //Documentation.FieldDescription = "Controls whether the Table Schema is applied to the data",
                                           //Documentation.SampleValues = {false}
                                       ]
                                   )
    )
    as table;

DataPackage.LoadContents = (
        dataPackageIdentifier as text,  // This can be a remote or local Data Package identifier
        ignoreTableSchemaTypes as text  // Ignore the Table Schema due to there being unhandled field values, types, and/or formatting
    ) as table =>
    let   
        // The Power BI Gateway Data Source settings seems to only show text parameters. As we've used a text value for ignoreTableSchemaTypes here, we need to convert it to a logical value.
        ignoreTableSchemaTypes =  if Text.Trim(ignoreTableSchemaTypes) = "" then 
                                      null
                                  else
                                      Logical.From(ignoreTableSchemaTypes),                                               
        DataResources = DataPackage.Tables(dataPackageIdentifier, ignoreTableSchemaTypes),  
        
        // Rename columns to meet the navigation table requirements
        NavigationReadyDataResources = Table.RenameColumns(
                                           DataResources,
                                           {
                                             {"name", "Name"},
                                             {"data", "Data"}
                                           }
                                       ),
        NonNullData = Table.SelectRows(NavigationReadyDataResources, each [Data] <> null and [Data] <> ""),
        TableWithItemKind = Table.AddColumn(NonNullData, "ItemKind", each "Table", Text.Type),
        TableWithItemName = Table.AddColumn(TableWithItemKind, "ItemName", each "Table", Text.Type),
        TableWithIsLeaf = Table.AddColumn(TableWithItemName, "IsLeaf", each "True", Text.Type),
        NavTable = Table.ToNavigationTable(TableWithIsLeaf, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

// Navigation Table
Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta 
        [
            NavigationTable.NameColumn = nameColumn, 
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn, 
            Preview.DelayColumn = itemNameColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;



    


