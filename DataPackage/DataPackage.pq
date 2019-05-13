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
    Beta = true,
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("Import data from a Data Package (Frictionless Data)") }, // ButtonText controls the 'Get Data' UI button text. The first item in the list defines the name of the button and the second controls the tooltip.
    LearnMoreUrl = "https://github.com/nimblelearn/datapackage-connector"
    //SourceImage = DataPackage.Icons,
    //SourceTypeImage = DataPackage.Icons
];

DataPackage.Icons = [
    Icon16 = { Extension.Contents("DataPackage16.png"), Extension.Contents("DataPackage20.png"), Extension.Contents("DataPackage24.png"), Extension.Contents("DataPackage32.png") },
    Icon32 = { Extension.Contents("DataPackage32.png"), Extension.Contents("DataPackage40.png"), Extension.Contents("DataPackage48.png"), Extension.Contents("DataPackage64.png") }
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
DataPackage.Tables = Extension.LoadFunction("DataPackageTables.pqm");

[DataSource.Kind="DataPackage", Publish="DataPackage.Publish"]
shared DataPackage.Load = (
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
        TableWithIsLeaf = Table.AddColumn(TableWithItemKind, "IsLeaf", each "True", Text.Type),
        NavTable = Table.ToNavigationTable(TableWithItemKind, {"Name"}, "Name", "Data", "ItemKind", "ItemKind", "IsLeaf")
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



    


