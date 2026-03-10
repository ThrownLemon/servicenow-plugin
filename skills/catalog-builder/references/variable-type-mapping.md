# Variable Type Integer Mapping

ServiceNow catalog variables use integer codes, not strings. The API silently ignores unrecognized values.

| User Says | Code | ServiceNow Type |
|-----------|------|-----------------|
| text, single line | 6 | Single Line Text |
| textarea, multi line | 2 | Multi Line Text |
| dropdown, select | 5 | Select Box |
| checkbox | 7 | Check Box |
| yes/no | 1 | Yes/No |
| reference | 8 | Reference |
| date | 9 | Date |
| date/time | 10 | Date/Time |
| number, numeric | 4 | Numeric Scale |
| masked, password | 26 | Masked |
| label | 21 | Label |
| break, separator | 22 | Break |
| container start | 19 | Container Start |
| container end | 20 | Container End |
| lookup select box | 25 | Lookup Select Box |
| list collector, multi-select | 11 | Lookup Multiple Choice |
| url | 18 | URL |
| macro | 14 | Macro |

## Notes

- There is no dedicated "email" variable type. For email input, use Single Line Text (6) with `regex_validation` for email format.
- For Reference types (8), set `reference` field to the target table name and optionally `reference_qual` for filtering.
- Select Box (5) variables require choices added via `catalog add-choice` after variable creation.
